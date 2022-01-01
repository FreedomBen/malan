defmodule Malan.TestUtilsTest do
  alias Malan.Test.Utils, as: TestUtils

  use ExUnit.Case, async: true

  describe "DateTime" do
    test "#plus_or_minus?/4" do
      {:ok, d1, 0} = DateTime.from_iso8601("2020-01-01T00:00:00Z")
      {:ok, d2, 0} = DateTime.from_iso8601("2020-01-09T00:00:00Z")
      {:ok, d3, 0} = DateTime.from_iso8601("2020-01-10T00:00:00Z")
      assert false == TestUtils.DateTime.plus_or_minus?(d1, d2, 1, :weeks)
      assert false == TestUtils.DateTime.plus_or_minus?(d2, d1, 1, :weeks)
      assert true == TestUtils.DateTime.plus_or_minus?(d2, d3, 1, :weeks)
      assert true == TestUtils.DateTime.plus_or_minus?(d3, d2, 1, :weeks)
    end

    test "#first_after_second_within?/4" do
      {:ok, d1, 0} = DateTime.from_iso8601("2020-01-01T00:00:00Z")
      {:ok, d2, 0} = DateTime.from_iso8601("2020-01-09T00:00:00Z")
      {:ok, d3, 0} = DateTime.from_iso8601("2020-01-10T00:00:00Z")
      assert false == TestUtils.DateTime.first_after_second_within?(d1, d2, 1, :weeks)
      assert false == TestUtils.DateTime.first_after_second_within?(d2, d1, 1, :weeks)
      assert false == TestUtils.DateTime.first_after_second_within?(d2, d3, 1, :weeks)
      assert true == TestUtils.DateTime.first_after_second_within?(d3, d2, 1, :weeks)
    end

    test "#within_last?/3" do
      # By testing weeks, we test all of the variations of #within_last?/3
      {:ok, d1, 0} = DateTime.from_iso8601("2020-01-01T00:00:00Z")
      d2 = DateTime.utc_now()
      assert false == TestUtils.DateTime.within_last?(d1, 1, :weeks)
      assert true == TestUtils.DateTime.within_last?(d2, 1, :weeks)
    end
  end
end
