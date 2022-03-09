defmodule Malan.RateLimitsTest do
  use Malan.DataCase, async: true

  alias Malan.RateLimits
  alias Malan.RateLimits.PasswordReset
  alias Malan.RateLimits.PasswordReset.{UpperLimit, LowerLimit}

  describe "Malan.RateLimits" do
    test "#check_rate/3" do
      # TODO
    end

    test "#clear/1" do
      # TODO
    end
  end

  describe "Malan.RateLimits.PasswordReset" do
    test "#check_rate/1" do
      # TODO
    end

    test "#clear/1" do
      # TODO
    end
  end

  describe "Malan.RateLimits.PasswordReset.LowerLimit" do
    def user_id_ll, do: "12344567890"
    def test_bucket_ll, do: UpperLimit.bucket(user_id_ll())

    test "#bucket/1" do
      assert "generate_password_reset_lower_limit:#{user_id_ll()}" == LowerLimit.bucket(user_id_ll())
    end

    test "#check_rate/1 and #clear/1" do
      # Should allow 1 every 3 minutes
      # Start with a clean slate to avoid pollution from previous tests
      # Make sure our settings are as expected
      assert 1 == Malan.Config.RateLimit.password_reset_lower_limit_count()
      assert 180_000 == Malan.Config.RateLimit.password_reset_lower_limit_msecs()

      assert {:ok, {0, 1, _, _, _}} = Hammer.inspect_bucket(test_bucket_ll(), 180_000, 1)
      assert {:allow, 1} = LowerLimit.check_rate(user_id_ll())

      assert {:ok, {0, 1, _, _, _}} = Hammer.inspect_bucket(test_bucket_ll(), 180_000, 1)
      assert {:deny, 1} = LowerLimit.check_rate(user_id_ll())

      assert {:ok, {0, 1, _, _, _}} = Hammer.inspect_bucket(test_bucket_ll(), 180_000, 1)
      assert {:deny, 1} = LowerLimit.check_rate(user_id_ll())

      assert {:ok, 1} = LowerLimit.clear(user_id_ll())
      assert {:ok, {0, 1, _, _, _}} = Hammer.inspect_bucket(test_bucket_ll(), 180_000, 1)
    end
  end

  describe "Malan.RateLimits.PasswordReset.UpperLimit" do
    def user_id_ul, do: "abcdefghijklmnopq"
    def test_bucket_ul, do: UpperLimit.bucket(user_id_ul())

    test "#bucket/1" do
      assert "generate_password_reset_upper_limit:#{user_id_ul()}" == UpperLimit.bucket(user_id_ul())

      # Make sure we have the right test bucket name
      assert test_bucket_ul() == UpperLimit.bucket(user_id_ul())
    end

    test "#check_rate/1 and #clear/1" do
      # Should allow 3 per day
      # Start with a clean slate to avoid pollution from previous tests
      # Make sure our settings are as expected
      assert 3 == Malan.Config.RateLimit.password_reset_upper_limit_count()
      assert 86_400_000 == Malan.Config.RateLimit.password_reset_upper_limit_msecs()

      assert {:ok, 0} = UpperLimit.clear(test_bucket_ul())

      assert {:ok, {0, 3, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
      assert {:allow, 1} = UpperLimit.check_rate(user_id_ul())

      assert {:ok, {1, 2, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
      assert {:allow, 2} = UpperLimit.check_rate(user_id_ul())

      assert {:ok, {2, 1, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
      assert {:allow, 3} = UpperLimit.check_rate(user_id_ul())

      assert {:ok, {3, 0, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
      assert {:deny, 3} = UpperLimit.check_rate(user_id_ul())

      assert {:ok, {4, 0, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
      assert {:deny, 3} = UpperLimit.check_rate(user_id_ul())

      assert {:ok, {5, 0, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)

      assert {:ok, 1} = UpperLimit.clear(user_id_ul())
      assert {:ok, {0, 3, _, _, _}} = Hammer.inspect_bucket(test_bucket_ul(), 86_400_000, 3)
    end
  end
end
