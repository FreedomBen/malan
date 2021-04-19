defmodule Malan.Test.Utils do
end

defmodule Malan.Test.Utils.DateTime do
  defp inner_compare(dt1, dt2, range), do:
    Enum.member?(range, DateTime.diff(dt1, dt2, :second))

  def plus_or_minus?(dt1, dt2, num, :seconds), do:
    inner_compare(dt1, dt2, Range.new(num * -1, num))

  def plus_or_minus?(dt1, dt2, num, :minutes), do:
    plus_or_minus?(dt1, dt2, num * 60, :seconds)

  def plus_or_minus?(dt1, dt2, num, :hours), do:
    plus_or_minus?(dt1, dt2, num * 60, :minutes)

  def plus_or_minus?(dt1, dt2, num, :days), do:
    plus_or_minus?(dt1, dt2, num * 24, :hours)

  def plus_or_minus?(dt1, dt2, num, :weeks), do:
    plus_or_minus?(dt1, dt2, num * 7, :days)

  def first_after_second_within?(dt1, dt2, num, :seconds), do:
    inner_compare(dt1, dt2, Range.new(0, num))

  def first_after_second_within?(dt1, dt2, num, :minutes), do:
    first_after_second_within?(dt1, dt2, num * 60, :seconds)

  def first_after_second_within?(dt1, dt2, num, :hours), do:
    first_after_second_within?(dt1, dt2, num * 60, :minutes)

  def first_after_second_within?(dt1, dt2, num, :days), do:
    first_after_second_within?(dt1, dt2, num * 24, :hours)

  def first_after_second_within?(dt1, dt2, num, :weeks), do:
    first_after_second_within?(dt1, dt2, num * 7, :days)

  def within_last?(dt, num, :seconds), do:
    inner_compare(DateTime.utc_now, dt, Range.new(0, num))

  def within_last?(dt, num, :minutes), do:
    within_last?(dt, num * 60, :seconds)

  def within_last?(dt, num, :hours), do:
    within_last?(dt, num * 60, :minutes)

  def within_last?(dt, num, :days), do:
    within_last?(dt, num * 24, :hours)

  def within_last?(dt, num, :weeks), do:
    within_last?(dt, num * 7, :days)
end
