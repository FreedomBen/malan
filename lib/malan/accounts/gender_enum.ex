defmodule Malan.Accounts.User.Gender do
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
      0 => "Agender",
      1 => "Androgyne",
      2 => "Androgynes",
      3 => "Androgynous",
      4 => "Bigender",
      5 => "Cis",
      6 => "Cis Female",
      7 => "Cis Male",
      8 => "Cis Man",
      9 => "Cis Woman",
      10 => "Cisgender",
      11 => "Cisgender Female",
      12 => "Cisgender Male",
      13 => "Cisgender Man",
      14 => "Cisgender Woman",
      15 => "Female to Male",
      16 => "FTM",
      17 => "Gender Fluid",
      18 => "Gender Nonconforming",
      19 => "Gender Questioning",
      20 => "Gender Variant",
      21 => "Genderqueer",
      22 => "Intersex",
      23 => "Male to Female",
      24 => "MTF",
      25 => "Neither",
      26 => "Neutrois",
      27 => "Non-binary",
      28 => "Other",
      29 => "Pangender",
      30 => "Trans",
      31 => "Trans Female",
      32 => "Trans Male",
      33 => "Trans Man",
      34 => "Trans Person",
      35 => "Trans*Female",
      36 => "Trans*Male",
      37 => "Trans*Man",
      38 => "Trans*Person",
      39 => "Trans*Woman",
      40 => "Transexual",
      41 => "Transexual Female",
      42 => "Transexual Male",
      43 => "Transexual Man",
      44 => "Transexual Person",
      45 => "Transexual Woman",
      46 => "Transgender Female",
      47 => "Transgender Person",
      48 => "Transmasculine",
      49 => "Two-spirit",
      50 => "Male",
      51 => "Female"
    }
  end

  def all_by_keyword() do
    %{
      "Agender" => 0,
      "Androgyne" => 1,
      "Androgynes" => 2,
      "Androgynous" => 3,
      "Bigender" => 4,
      "Cis" => 5,
      "Cis Female" => 6,
      "Cis Male" => 7,
      "Cis Man" => 8,
      "Cis Woman" => 9,
      "Cisgender" => 10,
      "Cisgender Female" => 11,
      "Cisgender Male" => 12,
      "Cisgender Man" => 13,
      "Cisgender Woman" => 14,
      "Female to Male" => 15,
      "FTM" => 16,
      "Gender Fluid" => 17,
      "Gender Nonconforming" => 18,
      "Gender Questioning" => 19,
      "Gender Variant" => 20,
      "Genderqueer" => 21,
      "Intersex" => 22,
      "Male to Female" => 23,
      "MTF" => 24,
      "Neither" => 25,
      "Neutrois" => 26,
      "Non-binary" => 27,
      "Other" => 28,
      "Pangender" => 29,
      "Trans" => 30,
      "Trans Female" => 31,
      "Trans Male" => 32,
      "Trans Man" => 33,
      "Trans Person" => 34,
      "Trans*Female" => 35,
      "Trans*Male" => 36,
      "Trans*Man" => 37,
      "Trans*Person" => 38,
      "Trans*Woman" => 39,
      "Transexual" => 40,
      "Transexual Female" => 41,
      "Transexual Male" => 42,
      "Transexual Man" => 43,
      "Transexual Person" => 44,
      "Transexual Woman" => 45,
      "Transgender Female" => 46,
      "Transgender Person" => 47,
      "Transmasculine" => 48,
      "Two-spirit" => 49,
      "Male" => 50,
      "Female" => 51
    }
  end
end
