defmodule Malan.Accounts.User.Ethnicity do
  def get(i) when is_integer(i), do: all_by_value()[i]
  def get(i) when is_binary(i), do: all_by_keyword_normalized()[normalize(i)]

  def to_s(nil), do: nil
  def to_s(i) when is_integer(i), do: get(i)
  def to_s(s) when is_binary(s), do: get(s)
  def to_i(nil), do: nil
  def to_i(s) when is_binary(s), do: get(s)

  def valid?(i) when is_nil(i), do: true
  def valid?(i) when is_integer(i), do: Map.has_key?(all_by_value, i)
  def valid?(i) when is_binary(i) do
    all_by_keyword
    |> Map.merge(all_by_keyword_normalized)
    |> Map.has_key?(i)
  end

  def valid_values(), do: Map.keys(all_by_keyword)
  def valid_values_str(), do: Enum.join(valid_values, ", ")

  def normalize(g) when is_binary(g), do: String.downcase(g)
  def normalize_key({k, v}) when is_binary(k), do: {normalize(k), v}
  def normalize_value({k, v}) when is_binary(v), do: {k, normalize(v)}
  def equal?(f, s), do: normalize(f) == normalize(s)

  def all_by_value_normalized() do
    all_by_value
    |> Enum.map(&normalize_value/1)
    |> Enum.into(%{})
  end

  def all_by_keyword_normalized() do
    all_by_keyword
    |> Enum.map(&normalize_key/1)
    |> Enum.into(%{})
  end

  def all_by_value() do
    %{
      0 => "Hispanic or Latinx",
      1 => "Not Hispanic or Latinx",
    }
  end

  def all_by_keyword() do
    %{
      "Hispanic or Latinx" => 0,
      "Not Hispanic or Latinx" => 1,
    }
  end
end
