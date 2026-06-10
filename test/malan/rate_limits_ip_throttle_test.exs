defmodule Malan.RateLimitsIpThrottleTest do
  # async: false — these tests lower the global per-IP login/registration
  # limits via Application.put_env. Nearly every concurrent test performs
  # fixture logins (create_session from a shared IP), so running these
  # alongside async tests would trip the lowered login bucket suite-wide.
  use Malan.DataCase, async: false

  alias Malan.RateLimits.{Login, Registration}

  setup do
    prev = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      prev
      |> Keyword.put(:login_ip_lower_limit_count, 5)
      |> Keyword.put(:login_ip_upper_limit_count, 30)
      |> Keyword.put(:registration_ip_lower_limit_count, 5)
    )

    on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, prev) end)

    :ok
  end

  describe "Malan.RateLimits.Login.PerIp" do
    test "#check_rate/1 allows up to the lower limit then denies" do
      ip = "203.0.113.31"
      assert {:ok, _} = Login.PerIp.clear(ip)

      assert 5 == Malan.Config.RateLimit.login_ip_lower_limit_count()
      assert 30 == Malan.Config.RateLimit.login_ip_upper_limit_count()

      Enum.each(1..5, fn i ->
        assert {:allow, ^i} = Login.PerIp.check_rate(ip)
      end)

      # 6th hit trips the lower-bucket deny
      assert {:deny, 5} = Login.PerIp.check_rate(ip)
      assert {:deny, 5} = Login.PerIp.check_rate(ip)

      assert {:ok, _} = Login.PerIp.clear(ip)
      assert {:allow, 1} = Login.PerIp.check_rate(ip)
      assert {:ok, _} = Login.PerIp.clear(ip)
    end

    test "buckets are per-IP" do
      ip_a = "198.51.100.30"
      ip_b = "198.51.100.40"

      assert {:ok, _} = Login.PerIp.clear(ip_a)
      assert {:ok, _} = Login.PerIp.clear(ip_b)

      # Saturate ip_a's lower bucket
      Enum.each(1..5, fn _ -> assert {:allow, _} = Login.PerIp.check_rate(ip_a) end)
      assert {:deny, _} = Login.PerIp.check_rate(ip_a)

      # ip_b is unaffected
      assert {:allow, 1} = Login.PerIp.check_rate(ip_b)

      assert {:ok, _} = Login.PerIp.clear(ip_a)
      assert {:ok, _} = Login.PerIp.clear(ip_b)
    end
  end

  describe "Malan.RateLimits.Registration.PerIp" do
    test "#check_rate/1 allows up to the lower limit then denies" do
      ip = "203.0.113.41"
      assert {:ok, _} = Registration.PerIp.clear(ip)

      Enum.each(1..5, fn i ->
        assert {:allow, ^i} = Registration.PerIp.check_rate(ip)
      end)

      assert {:deny, 5} = Registration.PerIp.check_rate(ip)

      assert {:ok, _} = Registration.PerIp.clear(ip)
      assert {:allow, 1} = Registration.PerIp.check_rate(ip)
      assert {:ok, _} = Registration.PerIp.clear(ip)
    end
  end

  describe "private-range exemption under lowered limits" do
    # Even with the limits lowered to 5, private (cluster-internal)
    # addresses never deny — they bypass the buckets entirely.
    test "private IPs are never denied by Login.PerIp or Registration.PerIp" do
      Enum.each(1..10, fn _ ->
        assert {:allow, 0} = Login.PerIp.check_rate("10.244.3.7")
        assert {:allow, 0} = Registration.PerIp.check_rate("10.244.3.7")
        assert {:allow, 0} = Malan.RateLimits.PasswordReset.PerIp.check_rate("10.244.3.7")
      end)
    end
  end
end
