defmodule MalanWeb.UserResetPasswordLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.RateLimits.PasswordReset
  alias Malan.RateLimits.PasswordReset.PerIp
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  defmodule FailingMailAdapter do
    @behaviour Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, {401, "unauthorized"}}

    @impl true
    def validate_config(_config), do: :ok
  end

  setup %{conn: conn} = context do
    set_swoosh_global(context)

    {:ok, conn: put_req_header(conn, "accept", "text/html")}
  end

  test "renders reset password form", %{conn: conn} do
    {:ok, _view, html} = live(conn, reset_path())

    assert html =~ "Reset Password"
    assert html =~ "Send Reset Email"
  end

  test "renders the same generic success message when the email is not found", %{conn: conn} do
    # Account-existence enumeration mitigation: a submitted address that
    # doesn't match any user must produce the same UI as a successful
    # reset request, so an attacker can't tell which email addresses
    # belong to real accounts.
    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => "missing@example.com"})

    assert html =~ "Reset request received"
    assert html =~ "missing@example.com"
    refute html =~ "No user matching that email address was found"
    assert_no_email_sent()
  end

  test "records an audit log row when the submitted email is unknown", %{conn: conn} do
    {:ok, view, _html} = live(conn, reset_path())
    _ = render_submit(view, "send_reset_email", %{"email" => "ghost@example.com"})

    log =
      Accounts.list_logs(0, 100)
      |> Enum.find(fn l ->
        l.what =~ "no user matching submitted email" and
          l.who_username == "ghost@example.com"
      end)

    refute is_nil(log), "expected an audit log row for the unknown-email attempt"
    assert log.success == false
    assert is_nil(log.user_id)
  end

  test "sends reset email and surfaces success message", %{conn: conn} do
    email = "live-reset-#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = AccountsHelpers.regular_user(%{email: email})

    on_exit(fn -> PasswordReset.clear(user.id) end)

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Reset request received"

    assert_email_sent(fn delivered ->
      assert delivered.subject == "Your requested password reset token"
      assert Enum.any?(delivered.to, fn {_name, address} -> address == user.email end)
      true
    end)

    db_user = Accounts.get_user_by_email(user.email)
    refute is_nil(db_user.password_reset_token_hash)
  end

  defp reset_path, do: ~p"/users/reset_password"

  test "shows rate limit error when reset requested too frequently", %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})

    on_exit(fn -> PasswordReset.clear(user.id) end)

    assert {:ok, _} = Accounts.generate_password_reset(user)

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Too many requests"
    assert_no_email_sent()
  end

  test "captures the LiveView peer IP in the audit log (not the legacy 0.0.0.0 stub)",
       %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})
    on_exit(fn -> PasswordReset.clear(user.id) end)

    conn =
      Plug.Conn.put_private(conn, :live_view_connect_info, %{
        peer_data: %{address: {203, 0, 113, 7}, port: 12_345, ssl_cert: nil}
      })

    {:ok, view, _html} = live(conn, reset_path())
    _ = render_submit(view, "send_reset_email", %{"email" => user.email})

    log =
      user.id
      |> Accounts.list_logs_by_user_id(0, 100)
      |> Enum.find(fn l -> l.what =~ "send_reset_email" end)

    refute is_nil(log), "expected an audit log row for send_reset_email"
    assert log.remote_ip == "203.0.113.7"
  end

  test "prefers the Cloudflare CF-Connecting-IP header over the peer_data",
       %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})
    on_exit(fn -> PasswordReset.clear(user.id) end)

    # peer_data is the Cloudflare edge; cf-connecting-ip is the visitor.
    conn =
      Plug.Conn.put_private(conn, :live_view_connect_info, %{
        peer_data: %{address: {172, 70, 1, 1}, port: 12_345, ssl_cert: nil},
        x_headers: [{"cf-connecting-ip", "198.51.100.42"}]
      })

    {:ok, view, _html} = live(conn, reset_path())
    _ = render_submit(view, "send_reset_email", %{"email" => user.email})

    log =
      user.id
      |> Accounts.list_logs_by_user_id(0, 100)
      |> Enum.find(fn l -> l.what =~ "send_reset_email" end)

    refute is_nil(log)
    assert log.remote_ip == "198.51.100.42"
  end

  test "throttles by Cloudflare IP after the per-IP limit, even with distinct emails",
       %{conn: conn} do
    # The per-user reset limit (1 / 3 minutes) won't trip when each
    # request submits a different identifier — that's the enumeration
    # side channel the per-IP limiter is meant to close. Use distinct
    # nonexistent emails so only the IP bucket can stop us.
    # Test config has per-IP counts set high to keep unrelated tests
    # from tripping the limiter; lower it just for this test.
    prev_cfg = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      Keyword.put(prev_cfg, :password_reset_ip_lower_limit_count, 5)
    )

    cf_ip = "198.51.100.77"

    on_exit(fn ->
      Application.put_env(:malan, Malan.Config.RateLimits, prev_cfg)
      PerIp.clear(cf_ip)
    end)

    submit = fn email ->
      conn =
        Plug.Conn.put_private(conn, :live_view_connect_info, %{
          peer_data: %{address: {172, 70, 1, 1}, port: 12_345, ssl_cert: nil},
          x_headers: [{"cf-connecting-ip", cf_ip}]
        })

      {:ok, view, _html} = live(conn, reset_path())
      render_submit(view, "send_reset_email", %{"email" => email})
    end

    # Lower IP bucket is 5 per minute (config/test.exs).
    Enum.each(1..5, fn i ->
      html = submit.("ip-throttle-#{i}@example.com")
      assert html =~ "Reset request received",
             "request #{i} should have been allowed but rendered: #{String.slice(html, 0, 200)}"
    end)

    html = submit.("ip-throttle-6@example.com")
    assert html =~ "Too many requests"
    refute html =~ "Reset request received"
  end

  test "per-IP throttle keys on the Cloudflare header, not the TCP peer",
       %{conn: conn} do
    # Same TCP peer (Cloudflare edge), but two different visitor IPs.
    # The second visitor's first request must succeed even though the
    # first visitor has already saturated their bucket — proving the
    # bucket key is the CF header, not peer_data.
    prev_cfg = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      Keyword.put(prev_cfg, :password_reset_ip_lower_limit_count, 5)
    )

    cf_ip_attacker = "198.51.100.88"
    cf_ip_victim = "198.51.100.99"

    on_exit(fn ->
      Application.put_env(:malan, Malan.Config.RateLimits, prev_cfg)
      PerIp.clear(cf_ip_attacker)
      PerIp.clear(cf_ip_victim)
    end)

    submit = fn cf_ip, email ->
      conn =
        Plug.Conn.put_private(conn, :live_view_connect_info, %{
          peer_data: %{address: {172, 70, 1, 1}, port: 12_345, ssl_cert: nil},
          x_headers: [{"cf-connecting-ip", cf_ip}]
        })

      {:ok, view, _html} = live(conn, reset_path())
      render_submit(view, "send_reset_email", %{"email" => email})
    end

    # Saturate the attacker's per-IP bucket (5 / min in test config).
    Enum.each(1..5, fn i ->
      _ = submit.(cf_ip_attacker, "atk-#{i}@example.com")
    end)

    deny_html = submit.(cf_ip_attacker, "atk-final@example.com")
    assert deny_html =~ "Too many requests"

    # A different CF IP through the same TCP peer is unaffected.
    allow_html = submit.(cf_ip_victim, "victim-1@example.com")
    assert allow_html =~ "Reset request received"
    refute allow_html =~ "Too many requests"
  end

  test "still surfaces success when mail provider rejects credentials (delivery is async)",
       %{conn: conn} do
    # Email delivery happens in an Oban worker, so SMTP credential failures
    # are handled by Oban retries and never reach the user. The LiveView
    # only reports whether the request was *accepted* (rate limit + token
    # generation), not whether SMTP eventually succeeded.
    prev_mailer_config = Application.get_env(:malan, Malan.Mailer)

    Application.put_env(
      :malan,
      Malan.Mailer,
      Keyword.put(prev_mailer_config, :adapter, FailingMailAdapter)
    )

    on_exit(fn -> Application.put_env(:malan, Malan.Mailer, prev_mailer_config) end)

    {:ok, user} = AccountsHelpers.regular_user(%{})

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Reset request received"
    refute html =~ "experienced an internal error"
  end
end
