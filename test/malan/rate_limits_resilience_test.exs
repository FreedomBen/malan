defmodule Malan.RateLimitsResilienceTest do
  # async: false — this test deliberately stops the shared Malan.RateLimiter
  # process tree, which would corrupt parallel tests that depend on it.
  use Malan.DataCase, async: false

  alias Malan.RateLimits

  describe "check_rate/3 with Redis unavailable" do
    setup do
      # Take the Hammer.Redis pool offline so the next pipeline! raises
      # %Redix.ConnectionError{}. on_exit restarts it so other test files
      # see a healthy limiter again.
      :ok = Supervisor.terminate_child(Malan.Supervisor, Malan.RateLimiter)

      on_exit(fn ->
        {:ok, _} = Supervisor.restart_child(Malan.Supervisor, Malan.RateLimiter)
      end)

      :ok
    end

    test "returns {:error, :rate_limiter_unavailable} instead of raising" do
      assert {:error, :rate_limiter_unavailable} =
               RateLimits.check_rate("resilience_test_bucket", 60_000, 5)
    end

    test "named buckets bubble :error up through the with-pipeline" do
      # PasswordReset.check_rate composes UpperLimit and LowerLimit via `with`;
      # the `:error` from either should fall through unchanged.
      assert {:error, :rate_limiter_unavailable} =
               RateLimits.PasswordReset.check_rate("resilience-user-id")

      assert {:error, :rate_limiter_unavailable} =
               RateLimits.Login.check_rate("resilience-username")

      assert {:error, :rate_limiter_unavailable} =
               RateLimits.Login.PerIp.check_rate("203.0.113.50")
    end

    test "login fails open when the rate limiter is unavailable" do
      # Both the per-IP and per-username login limiters return
      # {:error, :rate_limiter_unavailable} while Redis is down; a
      # correct-credentials login must still succeed.
      {:ok, user} = Malan.Test.Helpers.Accounts.regular_user()

      assert {:ok, %Malan.Accounts.Session{}} =
               Malan.Accounts.create_session(user.username, user.password, "203.0.113.60", %{
                 "ip_address" => "203.0.113.60"
               })
    end
  end
end
