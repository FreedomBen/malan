defmodule Malan.RateLimits do
  require Logger

  @spec check_rate(bucket :: String.t(), scale_ms :: integer, limit :: integer) ::
          {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}

  def check_rate(bucket, scale_ms, limit) do
    case Malan.RateLimiter.hit(bucket, scale_ms, limit) do
      {:allow, count} ->
        {:allow, count}

      {:deny, _timeout} ->
        {:deny, limit}
    end
  rescue
    # Hammer.Redis goes through Redix.pipeline! which raises on a dropped
    # connection (e.g. DigitalOcean managed Redis idle-disconnects an
    # otherwise healthy pool member). Surface as {:error, _} so callers
    # can decide their failure policy instead of crashing the request.
    e in [Redix.ConnectionError, Redix.Error] ->
      Logger.warning(
        "Rate limiter unavailable, returning :error for bucket=#{bucket}: #{Exception.message(e)}"
      )

      {:error, :rate_limiter_unavailable}
  catch
    # If the Redix pool itself is gone or its worker dies mid-call, Redix
    # raises an exit like {:redix_exited_during_call, _} or {:noproc, _}.
    # Treat as the same operational failure.
    :exit, reason ->
      Logger.warning(
        "Rate limiter exited mid-call, returning :error for bucket=#{bucket}: #{inspect(reason)}"
      )

      {:error, :rate_limiter_unavailable}
  end

  @spec clear(bucket :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

  def clear(bucket) do
    # Hammer.Redis with the default :fix_window algorithm stores one Redis
    # key per (prefix, bucket, window) triple. To wipe a bucket completely
    # we SCAN for `prefix:bucket:*` and DEL the matches in one pipeline.
    pattern = "#{Malan.RateLimiter.redis_prefix()}:#{bucket}:*"
    scan_and_delete(Malan.RateLimiter, pattern)
  end

  defp scan_and_delete(conn, pattern) do
    do_scan(conn, "0", pattern, 0)
  end

  defp do_scan(conn, cursor, pattern, deleted_acc) do
    case Redix.command(conn, ["SCAN", cursor, "MATCH", pattern, "COUNT", "100"]) do
      {:ok, [next_cursor, []]} ->
        if next_cursor == "0",
          do: {:ok, deleted_acc},
          else: do_scan(conn, next_cursor, pattern, deleted_acc)

      {:ok, [next_cursor, keys]} ->
        case Redix.command(conn, ["DEL" | keys]) do
          {:ok, n} when next_cursor == "0" ->
            {:ok, deleted_acc + n}

          {:ok, n} ->
            do_scan(conn, next_cursor, pattern, deleted_acc + n)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defmodule SessionExtension do
    @doc """
    Rate limit session extension attempts per user (non-admin).

    Returns {:allow, count} or {:deny, limit}.
    """
    @spec check_rate(user_id :: String.t()) ::
            {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
    def check_rate(user_id) do
      {msecs, count} = Malan.Config.RateLimit.session_extension_limit()

      user_id
      |> bucket()
      |> Malan.RateLimits.check_rate(msecs, count)
    end

    @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
    def clear(user_id) do
      user_id
      |> bucket()
      |> Malan.RateLimits.clear()
    end

    def bucket(user_id), do: "session_extension_limit:#{user_id}"
  end

  defmodule Login do
    @doc """
    Rate limit login attempts by username (applies even if the username is unknown).

    Returns {:allow, count} or {:deny, limit}.
    """
    @spec check_rate(username :: String.t()) ::
            {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
    def check_rate(username) do
      {msecs, count} = Malan.Config.RateLimit.login_limit()

      username
      |> bucket()
      |> Malan.RateLimits.check_rate(msecs, count)
    end

    @spec clear(username :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
    def clear(username) do
      username
      |> bucket()
      |> Malan.RateLimits.clear()
    end

    def bucket(username), do: "login_limit:#{username}"

    defmodule PerIp do
      # Rate limit login attempts by client IP, applied *before* the
      # per-username limit and before any DB work. The per-username
      # bucket alone doesn't bound an attacker: spraying random usernames
      # gets a fresh bucket on every request, and each attempt burns a
      # full-cost PBKDF2 verify (~100 ms CPU — fake_pass_verify/1 hashes
      # even for nonexistent users as a timing defense). This bucket caps
      # the hashing CPU a single source IP can consume.
      #
      # In production the IP arrives via the CF-Connecting-IP header
      # (rewritten onto conn.remote_ip by MalanWeb.Plugs.CloudflareRealIp
      # for HTTP, and read out of x_headers by MalanWeb.RealIp for
      # LiveView), so this is keyed on the visitor IP, not the
      # Cloudflare edge.

      alias Malan.RateLimits.Login.PerIp.{LowerLimit, UpperLimit}

      @spec check_rate(remote_ip :: String.t()) ::
              {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
      def check_rate(remote_ip) do
        with {:allow, _c1} <- UpperLimit.check_rate(remote_ip),
             {:allow, c2} <- LowerLimit.check_rate(remote_ip) do
          {:allow, c2}
        end
      end

      @spec clear(remote_ip :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
      def clear(remote_ip) do
        with {:ok, _c1} <- UpperLimit.clear(remote_ip),
             {:ok, c2} <- LowerLimit.clear(remote_ip) do
          {:ok, c2}
        end
      end

      defmodule LowerLimit do
        def bucket(remote_ip), do: "login_ip_lower_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.login_ip_lower_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end

      defmodule UpperLimit do
        def bucket(remote_ip), do: "login_ip_upper_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.login_ip_upper_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end
    end
  end

  defmodule Registration do
    defmodule PerIp do
      # Rate limit user registration by client IP, applied before any DB
      # work. POST /api/users is unauthenticated and each request runs a
      # full-cost PBKDF2 hash, inserts rows, and (with auto-send enabled)
      # enqueues a verification email — the same CPU-saturation exposure
      # as login, plus DB/email amplification. There is no per-user
      # equivalent for registration (the user doesn't exist yet), so the
      # per-IP bucket is the only throttle.
      #
      # In production the IP arrives via the CF-Connecting-IP header
      # (rewritten onto conn.remote_ip by MalanWeb.Plugs.CloudflareRealIp),
      # so this is keyed on the visitor IP, not the Cloudflare edge.

      alias Malan.RateLimits.Registration.PerIp.{LowerLimit, UpperLimit}

      @spec check_rate(remote_ip :: String.t()) ::
              {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
      def check_rate(remote_ip) do
        with {:allow, _c1} <- UpperLimit.check_rate(remote_ip),
             {:allow, c2} <- LowerLimit.check_rate(remote_ip) do
          {:allow, c2}
        end
      end

      @spec clear(remote_ip :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
      def clear(remote_ip) do
        with {:ok, _c1} <- UpperLimit.clear(remote_ip),
             {:ok, c2} <- LowerLimit.clear(remote_ip) do
          {:ok, c2}
        end
      end

      defmodule LowerLimit do
        def bucket(remote_ip), do: "registration_ip_lower_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.registration_ip_lower_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end

      defmodule UpperLimit do
        def bucket(remote_ip), do: "registration_ip_upper_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.registration_ip_upper_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end
    end
  end

  defmodule PasswordReset do
    alias Malan.RateLimits.PasswordReset.{UpperLimit, LowerLimit}

    @doc ~S"""
    Check if a password reset generation should be allowed or rate limitted

    If approved, returns {:allow, count}
    If unapproved, returns {:deny, limit}
    """
    @spec check_rate(user_id :: String.t()) ::
            {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}

    def check_rate(user_id) do
      # check upper limit rate first, then lower limit rate
      # For example, check daily limit first, then per minute limit
      with {:allow, _c1} <- UpperLimit.check_rate(user_id),
           {:allow, c2} <- LowerLimit.check_rate(user_id) do
        {:allow, c2}
      end
    end

    @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

    def clear(user_id) do
      with {:ok, _c1} <- UpperLimit.clear(user_id),
           {:ok, c2} <- LowerLimit.clear(user_id) do
        {:ok, c2}
      end
    end

    defmodule LowerLimit do
      def bucket(user_id), do: "generate_password_reset_lower_limit:#{user_id}"

      @spec check_rate(user_id :: String.t()) ::
              {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}

      def check_rate(user_id) do
        {msecs, count} = Malan.Config.RateLimit.password_reset_lower_limit()

        user_id
        |> bucket()
        |> Malan.RateLimits.check_rate(msecs, count)
      end

      @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

      def clear(user_id) do
        user_id
        |> bucket()
        |> Malan.RateLimits.clear()
      end
    end

    defmodule UpperLimit do
      def bucket(user_id), do: "generate_password_reset_upper_limit:#{user_id}"

      @spec check_rate(user_id :: String.t()) ::
              {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}

      def check_rate(user_id) do
        {msecs, count} = Malan.Config.RateLimit.password_reset_upper_limit()

        user_id
        |> bucket()
        |> Malan.RateLimits.check_rate(msecs, count)
      end

      @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

      def clear(user_id) do
        user_id
        |> bucket()
        |> Malan.RateLimits.clear()
      end
    end

    defmodule PerIp do
      # Rate limit password reset requests by client IP, applied *before*
      # the user lookup. This closes the enumeration side channel where an
      # attacker probes many identifiers (each per-user bucket starts
      # empty, so a script can fire one request per nonexistent username
      # without ever tripping the per-user limit).
      #
      # In production the IP arrives via the CF-Connecting-IP header
      # (rewritten onto conn.remote_ip by MalanWeb.Plugs.CloudflareRealIp
      # for HTTP, and read out of x_headers by MalanWeb.RealIp for
      # LiveView), so this is keyed on the visitor IP, not the
      # Cloudflare edge.

      alias Malan.RateLimits.PasswordReset.PerIp.{LowerLimit, UpperLimit}

      @spec check_rate(remote_ip :: String.t()) ::
              {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
      def check_rate(remote_ip) do
        with {:allow, _c1} <- UpperLimit.check_rate(remote_ip),
             {:allow, c2} <- LowerLimit.check_rate(remote_ip) do
          {:allow, c2}
        end
      end

      @spec clear(remote_ip :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
      def clear(remote_ip) do
        with {:ok, _c1} <- UpperLimit.clear(remote_ip),
             {:ok, c2} <- LowerLimit.clear(remote_ip) do
          {:ok, c2}
        end
      end

      defmodule LowerLimit do
        def bucket(remote_ip), do: "generate_password_reset_ip_lower_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.password_reset_ip_lower_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end

      defmodule UpperLimit do
        def bucket(remote_ip), do: "generate_password_reset_ip_upper_limit:#{remote_ip}"

        def check_rate(remote_ip) do
          {msecs, count} = Malan.Config.RateLimit.password_reset_ip_upper_limit()

          remote_ip
          |> bucket()
          |> Malan.RateLimits.check_rate(msecs, count)
        end

        def clear(remote_ip) do
          remote_ip
          |> bucket()
          |> Malan.RateLimits.clear()
        end
      end
    end
  end

  defmodule EmailVerification do
    alias Malan.RateLimits.EmailVerification.{LowerLimit, UpperLimit}

    @spec check_rate(user_id :: String.t()) ::
            {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}
    def check_rate(user_id) do
      with {:allow, _c1} <- UpperLimit.check_rate(user_id),
           {:allow, c2} <- LowerLimit.check_rate(user_id) do
        {:allow, c2}
      end
    end

    @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}
    def clear(user_id) do
      with {:ok, _c1} <- UpperLimit.clear(user_id),
           {:ok, c2} <- LowerLimit.clear(user_id) do
        {:ok, c2}
      end
    end

    defmodule LowerLimit do
      def bucket(user_id), do: "generate_email_verify_lower_limit:#{user_id}"

      def check_rate(user_id) do
        {msecs, count} = Malan.Config.RateLimit.email_verify_lower_limit()

        user_id
        |> bucket()
        |> Malan.RateLimits.check_rate(msecs, count)
      end

      def clear(user_id) do
        user_id
        |> bucket()
        |> Malan.RateLimits.clear()
      end
    end

    defmodule UpperLimit do
      def bucket(user_id), do: "generate_email_verify_upper_limit:#{user_id}"

      def check_rate(user_id) do
        {msecs, count} = Malan.Config.RateLimit.email_verify_upper_limit()

        user_id
        |> bucket()
        |> Malan.RateLimits.check_rate(msecs, count)
      end

      def clear(user_id) do
        user_id
        |> bucket()
        |> Malan.RateLimits.clear()
      end
    end
  end
end
