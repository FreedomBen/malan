defmodule Malan.Utils do
  def pry_pipe(retval) do
    require IEx; IEx.pry
    retval
  end

  def map_string_keys_to_atoms(map) do
    for {key, val} <- map, into: %{} do
      {String.to_atom(key), val}
    end
  end

  def map_atom_keys_to_strings(map) do
    for {key, val} <- map, into: %{} do
      {Atom.to_string(key), val}
    end
  end

  def struct_to_map(struct) do
    Map.from_struct(struct)
    |> Map.delete(:__meta__)
  end

  #def nil_or_empty?(nil), do: true
  #def nil_or_empty?(str) when is_string(str), do: "" == str |> String.trim()

  @doc """
  Checks if the passwed item is nil or empty string.  The param will be passed to to_string()
  and then trimmed and checked for empty string
  """
  def nil_or_empty?(str_or_nil) do
    "" == str_or_nil |> to_string() |> String.trim()
  end
end

defmodule Malan.Utils.Enum do
  @doc """
  Enum.all? will return true if all invocations of the function return
  true. Enum.none? is the opposite.  Enum.none? will return true if all
  invocations of the function return false.  If one returns true, the
  end result will be false
  """
  def none?(enum, func) do
    Enum.all?(enum, fn (i) -> !func.(i) end)
  end
end

defmodule Malan.Utils.Crypto do
  def strong_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64(padding: false)
    |> String.replace(~r{\+}, "C")
    |> String.replace(~r{/}, "z")
    |> binary_part(0, length)
  end

  def hash_password(password) do
    Pbkdf2.hash_pwd_salt(password)
  end

  def verify_password(given_pass, password_hash) do
    Pbkdf2.verify_pass(given_pass, password_hash)
  end

  def fake_verify_password() do
    Pbkdf2.no_user_verify()
  end

  def hash_token(api_token) do
    :crypto.hash(:sha256, api_token)
    |> Base.encode64()
  end
end

defmodule Malan.Utils.DateTime do
  def utc_now_trunc(),
    do: DateTime.truncate(DateTime.utc_now, :second)

  @doc "Return a DateTime about 200 years into the future"
  def distant_future() do
    round(52.5 * 200 * 7 * 24 * 60 * 60)
    |> adjust_cur_time_trunc(:seconds)
  end

  # New implementation, needs testing
  #def distant_future(),
    #do: adjust_cur_time(200, :years)

  def adjust_cur_time(num_years, :years),
    do: adjust_cur_time(round(num_years * 52.5), :weeks)

  def adjust_cur_time(num_weeks, :weeks),
    do: adjust_cur_time(num_weeks * 7, :days)

  def adjust_cur_time(num_days, :days),
    do: adjust_cur_time(num_days * 24, :hours)

  def adjust_cur_time(num_hours, :hours),
    do: adjust_cur_time(num_hours * 60, :minutes)

  def adjust_cur_time(num_minutes, :minutes),
    do: adjust_cur_time(num_minutes * 60, :seconds)

  def adjust_cur_time(num_seconds, :seconds),
    do: adjust_time(DateTime.utc_now, num_seconds, :seconds)

  def adjust_cur_time_trunc(num_weeks, :weeks),
    do: adjust_cur_time_trunc(num_weeks * 7, :days)

  def adjust_cur_time_trunc(num_days, :days),
    do: adjust_cur_time_trunc(num_days * 24, :hours)

  def adjust_cur_time_trunc(num_hours, :hours),
    do: adjust_cur_time_trunc(num_hours * 60, :minutes)

  def adjust_cur_time_trunc(num_minutes, :minutes),
    do: adjust_cur_time_trunc(num_minutes * 60, :seconds)

  def adjust_cur_time_trunc(num_seconds, :seconds),
    do: adjust_time(utc_now_trunc(), num_seconds, :seconds)

  def adjust_time(time, num_weeks, :weeks),
    do: adjust_time(time, num_weeks * 7, :days)

  def adjust_time(time, num_days, :days),
    do: adjust_time(time, num_days * 24, :hours)

  def adjust_time(time, num_hours, :hours),
    do: adjust_time(time, num_hours * 60, :minutes)

  def adjust_time(time, num_minutes, :minutes),
    do: adjust_time(time, num_minutes * 60, :seconds)

  def adjust_time(time, num_seconds, :seconds),
    do: DateTime.add(time, num_seconds, :second)

  def expired?(expires_at, current_time),
    do: DateTime.compare(expires_at, current_time) != :gt

  def expired?(nil),
    do: raise ArgumentError, message: "expires_at time must not be nil!"

  def expired?(expires_at),
    do: expired?(expires_at, DateTime.utc_now)

end
