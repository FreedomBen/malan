defmodule Malan.RateLimits do
  @spec check_rate(bucket :: String.t(), scale_ms :: integer, limit :: integer) ::
    {:allow, count :: integer()} | {:deny, limit :: integer()} | {:error, reason :: any}

  def check_rate(bucket, msecs, count) do
    Hammer.check_rate(bucket, msecs, count)
  end

  @spec clear(bucket :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

  def clear(bucket) do
    Hammer.delete_buckets(bucket)
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
           {:allow,  c2} <- LowerLimit.check_rate(user_id) do
        {:allow, c2}
      end
    end

    @spec clear(user_id :: String.t()) :: {:ok, count :: integer} | {:error, reason :: any}

    def clear(user_id) do
      with {:ok, _c1} <- UpperLimit.clear(user_id),
           {:ok,  c2} <- LowerLimit.clear(user_id) do
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
  end
end
