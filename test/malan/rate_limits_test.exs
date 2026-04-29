defmodule Malan.RateLimitsTest do
  use Malan.DataCase, async: true

  alias Malan.RateLimits.PasswordReset
  alias Malan.RateLimits.PasswordReset.{UpperLimit, LowerLimit}
  alias Malan.RateLimits.PasswordReset.PerIp

  # This is covered indirectly by the other tests
  describe "Malan.RateLimits" do
  end

  describe "Malan.RateLimits.PasswordReset" do
    def user_id_pr, do: "akljetq4oihjghkj"

    test "#check_rate/1 and #clear/1" do
      # Should allow 1 every 3 minutes
      # Start with a clean slate to avoid pollution from previous tests
      assert {:ok, 0} = PasswordReset.clear(user_id_pr())

      assert {:allow, 1} = PasswordReset.check_rate(user_id_pr())
      assert {:deny, 1} = PasswordReset.check_rate(user_id_pr())
      assert {:deny, 1} = PasswordReset.check_rate(user_id_pr())

      assert {:ok, 1} = PasswordReset.clear(user_id_pr())

      assert {:allow, 1} = PasswordReset.check_rate(user_id_pr())
      assert {:deny, 1} = PasswordReset.check_rate(user_id_pr())

      assert {:ok, 1} = PasswordReset.clear(user_id_pr())
    end
  end

  describe "Malan.RateLimits.PasswordReset.LowerLimit" do
    def user_id_ll, do: "12344567890"
    def test_bucket_ll, do: LowerLimit.bucket(user_id_ll())

    test "#bucket/1" do
      assert "generate_password_reset_lower_limit:#{user_id_ll()}" ==
               LowerLimit.bucket(user_id_ll())
    end

    test "#check_rate/1 and #clear/1" do
      # Should allow 1 every 3 minutes
      # Start with a clean slate to avoid pollution from previous tests
      # Make sure our settings are as expected
      assert 1 == Malan.Config.RateLimit.password_reset_lower_limit_count()
      assert 180_000 == Malan.Config.RateLimit.password_reset_lower_limit_msecs()

      assert {:ok, 0} = LowerLimit.clear(user_id_ll())
      assert 0 == Malan.RateLimiter.get(test_bucket_ll(), 180_000)

      assert {:allow, 1} = LowerLimit.check_rate(user_id_ll())

      assert 1 == Malan.RateLimiter.get(test_bucket_ll(), 180_000)
      assert {:deny, 1} = LowerLimit.check_rate(user_id_ll())

      assert 2 == Malan.RateLimiter.get(test_bucket_ll(), 180_000)
      assert {:deny, 1} = LowerLimit.check_rate(user_id_ll())

      assert {:ok, 1} = LowerLimit.clear(user_id_ll())
      assert 0 == Malan.RateLimiter.get(test_bucket_ll(), 180_000)
    end
  end

  describe "Malan.RateLimits.PasswordReset.UpperLimit" do
    def user_id_ul, do: "abcdefghijklmnopq"
    def test_bucket_ul, do: UpperLimit.bucket(user_id_ul())

    test "#bucket/1" do
      assert "generate_password_reset_upper_limit:#{user_id_ul()}" ==
               UpperLimit.bucket(user_id_ul())

      # Make sure we have the right test bucket name
      assert test_bucket_ul() == UpperLimit.bucket(user_id_ul())
    end

    test "#check_rate/1 and #clear/1" do
      # Should allow 3 per day
      # Start with a clean slate to avoid pollution from previous tests
      # Make sure our settings are as expected
      assert 3 == Malan.Config.RateLimit.password_reset_upper_limit_count()
      assert 86_400_000 == Malan.Config.RateLimit.password_reset_upper_limit_msecs()

      assert {:ok, 0} = UpperLimit.clear(user_id_ul())
      assert 0 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:allow, 1} = UpperLimit.check_rate(user_id_ul())
      assert 1 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:allow, 2} = UpperLimit.check_rate(user_id_ul())
      assert 2 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:allow, 3} = UpperLimit.check_rate(user_id_ul())
      assert 3 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:deny, 3} = UpperLimit.check_rate(user_id_ul())
      assert 4 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:deny, 3} = UpperLimit.check_rate(user_id_ul())
      assert 5 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)

      assert {:ok, 1} = UpperLimit.clear(user_id_ul())
      assert 0 == Malan.RateLimiter.get(test_bucket_ul(), 86_400_000)
    end
  end

  describe "Malan.RateLimits.PasswordReset.PerIp" do
    # Test config sets the per-IP counts to 1_000_000 so unrelated tests
    # don't trip the limit. Inside this describe we lower it to 5 / min so
    # we can exercise the deny path. async: false on this describe to
    # avoid clobbering Application env from parallel tests.
    @tag :perip_limit_override
    setup tags do
      if tags[:perip_limit_override] do
        prev = Application.get_env(:malan, Malan.Config.RateLimits)

        Application.put_env(
          :malan,
          Malan.Config.RateLimits,
          prev
          |> Keyword.put(:password_reset_ip_lower_limit_count, 5)
          |> Keyword.put(:password_reset_ip_upper_limit_count, 30)
        )

        on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, prev) end)
      end

      :ok
    end

    def remote_ip_pi, do: "203.0.113.7"

    @tag :perip_limit_override
    test "#check_rate/1 allows up to the lower limit then denies" do
      assert {:ok, _} = PerIp.clear(remote_ip_pi())

      assert 5 == Malan.Config.RateLimit.password_reset_ip_lower_limit_count()
      assert 30 == Malan.Config.RateLimit.password_reset_ip_upper_limit_count()

      assert {:allow, 1} = PerIp.check_rate(remote_ip_pi())
      assert {:allow, 2} = PerIp.check_rate(remote_ip_pi())
      assert {:allow, 3} = PerIp.check_rate(remote_ip_pi())
      assert {:allow, 4} = PerIp.check_rate(remote_ip_pi())
      assert {:allow, 5} = PerIp.check_rate(remote_ip_pi())
      # 6th hit trips the lower-bucket deny
      assert {:deny, 5} = PerIp.check_rate(remote_ip_pi())
      assert {:deny, 5} = PerIp.check_rate(remote_ip_pi())

      assert {:ok, _} = PerIp.clear(remote_ip_pi())
      assert {:allow, 1} = PerIp.check_rate(remote_ip_pi())
      assert {:ok, _} = PerIp.clear(remote_ip_pi())
    end

    @tag :perip_limit_override
    test "buckets are per-IP" do
      ip_a = "198.51.100.10"
      ip_b = "198.51.100.20"

      assert {:ok, _} = PerIp.clear(ip_a)
      assert {:ok, _} = PerIp.clear(ip_b)

      # Saturate ip_a's lower bucket
      Enum.each(1..5, fn _ -> assert {:allow, _} = PerIp.check_rate(ip_a) end)
      assert {:deny, _} = PerIp.check_rate(ip_a)

      # ip_b is unaffected
      assert {:allow, 1} = PerIp.check_rate(ip_b)

      assert {:ok, _} = PerIp.clear(ip_a)
      assert {:ok, _} = PerIp.clear(ip_b)
    end
  end

  describe "Malan.RateLimits.PasswordReset.PerIp.LowerLimit" do
    alias Malan.RateLimits.PasswordReset.PerIp.LowerLimit, as: IpLowerLimit

    test "#bucket/1" do
      assert "generate_password_reset_ip_lower_limit:203.0.113.99" ==
               IpLowerLimit.bucket("203.0.113.99")
    end
  end

  describe "Malan.RateLimits.PasswordReset.PerIp.UpperLimit" do
    alias Malan.RateLimits.PasswordReset.PerIp.UpperLimit, as: IpUpperLimit

    test "#bucket/1" do
      assert "generate_password_reset_ip_upper_limit:203.0.113.99" ==
               IpUpperLimit.bucket("203.0.113.99")
    end
  end
end
