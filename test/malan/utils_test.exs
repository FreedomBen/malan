defmodule Malan.UtilsTest do
  alias Malan.Utils

  use ExUnit.Case, async: true

  describe "main" do
    test "nil_or_empty?/1" do
      assert true == Utils.nil_or_empty?(nil)
      assert true == Utils.nil_or_empty?("")
      assert false == Utils.nil_or_empty?("abcd")
      assert false == Utils.nil_or_empty?(42)
    end
  end

  describe "Crypto" do
    test "#strong_random_string" do
      str = Utils.Crypto.strong_random_string(12)
      assert String.length(str) == 12
      assert str =~ ~r/^[A-Za-z0-9]{12}/
    end
  end

  describe "DateTime" do
    # This exercises all of the adjust_yyy_time funcs since they call each other
    test "adjust_cur_time weeks" do
      adjusted = Utils.DateTime.adjust_cur_time(2, :weeks)
      manually = DateTime.add(DateTime.utc_now, 2 * 7 * 24 * 60 * 60, :second)
      diff = DateTime.diff(manually, adjusted, :second)
      # Possibly flakey test. These numbers might be too close.
      # Changed 1 to 2, hopefully that is fuzzy enough to work
      assert diff >= 0 && diff < 2
    end

    test "adjust_time weeks" do
    # This exercises all of the adjust_time funcs since they call each other
      start_dt = DateTime.utc_now
      assert DateTime.add(start_dt, 2 * 7 * 24 * 60 * 60, :second) == Utils.DateTime.adjust_time(start_dt, 2, :weeks)
    end
  end

  describe "Enum" do
    test "#none?" do
      input = ["one", "two", "three"]
      assert true  == Utils.Enum.none?(input, fn (i) -> i == "four" end)
      assert false == Utils.Enum.none?(input, fn (i) -> i == "three" end)
    end
  end
end
