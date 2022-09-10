defmodule Malan.TestUtilsTest do
  alias Malan.Test.Utils, as: TestUtils

  use ExUnit.Case, async: true

  describe "TestUtils" do
    defp fy, do: "Fort Yuma"
    defp fa, do: "Fort Apache"
    defp gc, do: "General Crook"

    # l1 and l2 are equal (though out of order)
    defp l1, do: [%{id: 1, name: fa()}, %{id: 3, name: fy()}, %{id: 2, name: gc()}]
    defp l2, do: [%{id: 2, name: gc()}, %{id: 1, name: fa()}, %{id: 3, name: fy()}]

    # l3 and l4 are unique (different than l1 and l2 and each other)
    defp l3, do: [%{id: 2, name: fa()}, %{id: 1, name: fy()}, %{id: 3, name: gc()}]
    defp l4, do: [%{id: 2, name: fy()}, %{id: 1, name: gc()}, %{id: 3, name: fa()}]

    defp l5, do: [3, 1, 2]
    defp l6, do: [1, 3, 2]

    defp l1_id_asc, do: [%{id: 1, name: fa()}, %{id: 2, name: gc()}, %{id: 3, name: fy()}]
    defp l1_id_desc, do: [%{id: 3, name: fy()}, %{id: 2, name: gc()}, %{id: 1, name: fa()}]

    defp l1_name_asc, do: [%{id: 1, name: fa()}, %{id: 3, name: fy()}, %{id: 2, name: gc()}]
    defp l1_name_desc, do: [%{id: 2, name: gc()}, %{id: 3, name: fy()}, %{id: 1, name: fa()}]

    test "#lists_equal_ignore_order/2 works" do
      assert TestUtils.lists_equal_ignore_order(l1(), l2())
      assert TestUtils.lists_equal_ignore_order(l2(), l1())

      assert TestUtils.lists_equal_ignore_order(l5(), l5())
      assert TestUtils.lists_equal_ignore_order(l5(), l6())
      assert TestUtils.lists_equal_ignore_order(l6(), l6())

      assert not TestUtils.lists_equal_ignore_order(l1(), l3())
      assert not TestUtils.lists_equal_ignore_order(l1(), l4())
      assert not TestUtils.lists_equal_ignore_order(l2(), l3())
      assert not TestUtils.lists_equal_ignore_order(l2(), l4())

      assert not TestUtils.lists_equal_ignore_order(l2(), l5())
    end

    test "#lists_equal_ignore_order/3 properly shows equal" do
      assert TestUtils.lists_equal_ignore_order(l1(), l2(), &(&1))
      assert TestUtils.lists_equal_ignore_order(l5(), l6(), &(&1))
      assert TestUtils.lists_equal_ignore_order(l1(), l2(), &(&1.id))
      assert TestUtils.lists_equal_ignore_order(l1(), l2(), &(&1.name))
      assert TestUtils.lists_equal_ignore_order(l1(), l2(), &("Henry Fonda" <> &1.name))

      assert not TestUtils.lists_equal_ignore_order(l1(), l3(), &(&1))
      assert not TestUtils.lists_equal_ignore_order(l1(), l4(), &(&1))
      assert not TestUtils.lists_equal_ignore_order(l2(), l3(), &(&1))
      assert not TestUtils.lists_equal_ignore_order(l2(), l4(), &(&1))

      assert not TestUtils.lists_equal_ignore_order(l1(), l3(), &(&1.id))
      assert not TestUtils.lists_equal_ignore_order(l1(), l4(), &(&1.id))
      assert not TestUtils.lists_equal_ignore_order(l2(), l3(), &(&1.id))
      assert not TestUtils.lists_equal_ignore_order(l2(), l4(), &(&1.id))

      assert not TestUtils.lists_equal_ignore_order(l1(), l3(), &(&1.name))
      assert not TestUtils.lists_equal_ignore_order(l1(), l4(), &(&1.name))
      assert not TestUtils.lists_equal_ignore_order(l2(), l3(), &(&1.name))
      assert not TestUtils.lists_equal_ignore_order(l2(), l4(), &(&1.name))

      assert not TestUtils.lists_equal_ignore_order(l1(), l3(), &("Henry Fonda" <> &1.name))
      assert not TestUtils.lists_equal_ignore_order(l1(), l4(), &("Henry Fonda" <> &1.name))
      assert not TestUtils.lists_equal_ignore_order(l2(), l3(), &("Henry Fonda" <> &1.name))
      assert not TestUtils.lists_equal_ignore_order(l2(), l4(), &("Henry Fonda" <> &1.name))
    end

    test "#sort_by/3 sorts in proper order" do
      assert l1_id_asc() == TestUtils.sort_by(l1(), &(&1.id))
      assert l1_id_asc() == TestUtils.sort_by(l1(), &(&1.id), :asc)

      assert l1_id_desc() == TestUtils.sort_by(l1(), &(&1.id), :desc)

      assert l1_name_asc() == TestUtils.sort_by(l1(), &(&1.name))
      assert l1_name_asc() == TestUtils.sort_by(l1(), &(&1.name), :asc)

      assert l1_name_desc() == TestUtils.sort_by(l1(), &(&1.name), :desc)
    end

    test "#sort_by_id/3 sorts in proper order by id" do
      assert l1_id_asc() == TestUtils.sort_by_id(l1())
      assert l1_id_asc() == TestUtils.sort_by_id(l1(), :asc)

      assert l1_id_desc() == TestUtils.sort_by_id(l1(), :desc)
    end
  end

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
