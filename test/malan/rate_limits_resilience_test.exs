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
    end
  end
end
