defmodule Malan.Test.Utils do
  def lists_equal_ignore_order(list1, list2) do
    lists_equal_ignore_order(list1, list2, &(&1))
  end

  def lists_equal_ignore_order(list1, list2, mapper, type \\ :asc) do
    l1 = Enum.sort_by(list1, mapper, type)
    l2 = Enum.sort_by(list2, mapper, type)
    l1 == l2
  end

  def lists_equal_ignore_order_sort_by_id(list1, list2) do
    lists_equal_ignore_order(list1, list2, &(&1.id))
  end

  def sort_by(list, mapper, type \\ :asc) do
    Enum.sort_by(list, mapper, type)
  end

  def sort_by_id(list, type \\ :asc) do
    Enum.sort_by(list, &(&1.id), type)
  end
end

defmodule Malan.Test.Utils.Controller do
  def set_params(%Plug.Conn{} = conn, new_params) do
    conn
    |> Map.put(:params, new_params)
  end

  def add_params(%Plug.Conn{params: params} = conn, new_params) do
    conn
    |> set_params(Map.merge(params, new_params))
  end
end

defmodule Malan.Test.Utils.DateTime do
  defp inner_compare(dt1, dt2, range), do: Enum.member?(range, DateTime.diff(dt1, dt2, :second))

  @doc ~S"""
  check if `dt1` and `dt2` are within `num` units of each other
  """
  def plus_or_minus?(dt1, dt2, num, :seconds),
    do: inner_compare(dt1, dt2, Range.new(num * -1, num))

  def plus_or_minus?(dt1, dt2, num, :minutes), do: plus_or_minus?(dt1, dt2, num * 60, :seconds)

  def plus_or_minus?(dt1, dt2, num, :hours), do: plus_or_minus?(dt1, dt2, num * 60, :minutes)

  def plus_or_minus?(dt1, dt2, num, :days), do: plus_or_minus?(dt1, dt2, num * 24, :hours)

  def plus_or_minus?(dt1, dt2, num, :weeks), do: plus_or_minus?(dt1, dt2, num * 7, :days)

  @doc ~S"""
  Check if the first `DateTime` is within `num` units of the second DateTime
  """
  def first_after_second_within?(dt1, dt2, num, :seconds),
    do: inner_compare(dt1, dt2, Range.new(0, num))

  def first_after_second_within?(dt1, dt2, num, :minutes),
    do: first_after_second_within?(dt1, dt2, num * 60, :seconds)

  def first_after_second_within?(dt1, dt2, num, :hours),
    do: first_after_second_within?(dt1, dt2, num * 60, :minutes)

  def first_after_second_within?(dt1, dt2, num, :days),
    do: first_after_second_within?(dt1, dt2, num * 24, :hours)

  def first_after_second_within?(dt1, dt2, num, :weeks),
    do: first_after_second_within?(dt1, dt2, num * 7, :days)

  @doc ~S"""
  Check if the specified datetime references a time within the last `num` of units
  """
  def within_last?(dt, num, :seconds),
    do: inner_compare(DateTime.utc_now(), dt, Range.new(0, num))

  def within_last?(dt, num, :minutes), do: within_last?(dt, num * 60, :seconds)

  def within_last?(dt, num, :hours), do: within_last?(dt, num * 60, :minutes)

  def within_last?(dt, num, :days), do: within_last?(dt, num * 24, :hours)

  def within_last?(dt, num, :weeks), do: within_last?(dt, num * 7, :days)
end
