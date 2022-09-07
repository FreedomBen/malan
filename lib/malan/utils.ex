defmodule Malan.Utils do
  @doc ~S"""
  Using either `key` or `extract_func`, extract the specified thing.

  Alias is `process()` and `transform()`

  This is very useful for converting some value into another in a pipeline,
  such as unwrapping a structure or transforming it.  It's essentially like
  `Enum.map/2` but only operates on a single object rather than an `Enumerable`

  Example:

  ```
  some_function_returns_a_map()
  |> Malan.Utils.extract(:data)  # extract the 'data' key from map
  |> Enum.map(...)

  get_user()
  |> Malan.Utils.extract(:age)
  |> handle_age()

  get_user()
  |> Malan.Utils.extract(%{name: "Jeb", age: 37}, fn {:ok, user} -> user)
  |> extract()
  ```
  ## iex examples:

    iex> Malan.Utils.extract(%{name: "Jeb", age: 37}, :age)
    37

    iex> Malan.Utils.extract(%{name: "Jeb", age: 37}, fn arg -> arg[:age] * 2 end)
    74
  """
  @spec extract(
          Access.t() | list() | tuple() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def extract(list, key) when is_list(list) and is_integer(key) do
    Enum.at(list, key)
  end

  def extract(tuple, key) when is_tuple(tuple) and is_integer(key) do
    elem(tuple, key)
  end

  def extract(struct, key) when is_struct(struct) and is_atom(key) do
    Map.from_struct(struct)[key]
  end

  def extract(struct, key) when is_struct(struct) and is_binary(key) do
    extract(struct, String.to_atom(key))
  end

  def extract(access, key) when is_atom(key) or is_binary(key) do
    access[key]
  end

  def extract(anything, extract_func) do
    extract_func.(anything)
  end

  @spec process(
          Access.t() | list() | tuple() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def process(thing, arg), do: extract(thing, arg)

  @spec transform(
          Access.t() | list() | tuple() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def transform(thing, arg), do: extract(thing, arg)

  @doc ~S"""
  Macro that makes a function public in test, private in non-test

  See:  https://stackoverflow.com/a/47598190/2062384
  """
  defmacro defp_testable(head, body \\ nil) do
    if Mix.env() == :test do
      quote do
        def unquote(head) do
          unquote(body[:do])
        end
      end
    else
      quote do
        defp unquote(head) do
          unquote(body[:do])
        end
      end
    end
  end

  @doc ~S"""
  Easy drop-in to a pipe to inspect the return value of the previous function.

  ## Examples

      conn
      |> put_status(:not_found)
      |> put_view(MalanWeb.ErrorView)
      |> render(:"404")
      |> pry_pipe()

  ## Alternatives

  You may also wish to consider using `IO.inspect/3` in pipelines.  `IO.inspect/3`
  will print and return the value unchanged.  Example:

      conn
      |> put_status(:not_found)
      |> IO.inspect(label: "after status")
      |> render(:"404")

  """
  def pry_pipe(retval, arg1 \\ nil, arg2 \\ nil, arg3 \\ nil, arg4 \\ nil) do
    require IEx
    IEx.pry()
    retval
  end

  @doc ~S"""
  Retrieve syntax colors for embedding into `:syntax_colors` of `Inspect.Opts`

  You probably don't want this directly.  You probably want `inspect_format`
  """
  def inspect_syntax_colors do
    [
      number: :yellow,
      atom: :cyan,
      string: :green,
      boolean: :magenta,
      nil: :magenta
    ]
  end

  @doc ~S"""
  Get `Inspect.Opts` for `Kernel.inspect` or `IO.inspect`

  If `opaque_struct` is false, then structs will be printed as `Map`s, which
  allows you to see any opaque fields they might have set

  `limit` is the max number of stuff printed out.  Can be an integer or `:infinity`
  """
  def inspect_format(opaque_struct \\ true, limit \\ 50) do
    [
      structs: opaque_struct,
      limit: limit,
      syntax_colors: inspect_syntax_colors(),
      width: 80
    ]
  end

  @doc ~S"""
  Runs `IO.inspect/2` with pretty printing, colors, and unlimited size.

  If `opaque_struct` is false, then structs will be printed as `Map`s, which
  allows you to see any opaque fields they might have set
  """
  def inspect(val, opaque_struct \\ true, limit \\ 50) do
    Kernel.inspect(val, inspect_format(opaque_struct, limit))
  end

  @doc ~S"""
  Convert a map with `String` keys into a map with `Atom` keys.

  ## Examples

      iex> Malan.Utils.map_string_keys_to_atoms(%{"one" => "one", "two" => "two"})
      %{one: "one", two: "two"}m

  """
  def map_string_keys_to_atoms(map) do
    for {key, val} <- map, into: %{} do
      {String.to_atom(key), val}
    end
  end

  @doc ~S"""
  Convert a map with `String` keys into a map with `Atom` keys.

  ## Examples

      iex> Malan.Utils.map_atom_keys_to_strings(%{one: "one", two: "two"})
      %{"one" => "one", "two" => "two"}

  """
  def map_atom_keys_to_strings(map) do
    for {key, val} <- map, into: %{} do
      {Atom.to_string(key), val}
    end
  end

  @doc ~S"""
  Converts a struct to a regular map by deleting the `:__meta__` key

  ## Examples

      Malan.Utils.struct_to_map(%Something{hello: "world"})
      %{hello: "world"}

  """
  def struct_to_map(struct, mask_keys \\ []) do
    Map.from_struct(struct)
    |> Map.delete(:__meta__)
    |> mask_map_key_values(mask_keys)
  end

  @doc ~S"""
  Takes a map and a list of keys whose values should be masked

  ## Examples

      iex> Malan.Utils.mask_map_key_values(%{name: "Ben, title: "Lord"}, [:title])
      %{name: "Ben", title: "****"}

      iex> Malan.Utils.mask_map_key_values(%{name: "Ben, age: 39}, [:age])
      %{name: "Ben", age: "**"}
  """
  def mask_map_key_values(map, mask_keys) do
    map
    |> Enum.map(fn {key, val} ->
      case key in list_to_strings_and_atoms(mask_keys) do
        true -> {key, mask_str(val)}
        _ -> {key, val}
      end
    end)
    |> Enum.into(%{})
  end

  @doc ~S"""
  Generate a new random UUIDv4

  ## Examples

      Malan.Utils.uuidgen()
      "4c2fd8d3-a6e3-4e4b-a2ce-3f21456eeb85"

  """
  def uuidgen(),
    do: bingenerate() |> encode()

  @doc ~S"""
  Quick regex check to see if the supplied `string` is a valid UUID

  Check is done by simple regular expression and is not overly sophisticated.

  Return true || false

  ## Examples

      iex> Malan.Utils.is_uuid?(nil)
      false
      iex> Malan.Utils.is_uuid?("hello world")
      false
      iex> Malan.Utils.is_uuid?("4c2fd8d3-a6e3-4e4b-a2ce-3f21456eeb85")
      true

  """
  def is_uuid?(nil), do: false

  def is_uuid?(string),
    do:
      string =~ ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

  def is_uuid_or_nil?(nil), do: true
  def is_uuid_or_nil?(string), do: is_uuid?(string)

  # def nil_or_empty?(nil), do: true
  # def nil_or_empty?(str) when is_string(str), do: "" == str |> String.trim()

  @doc """
  Checks if the passed item is nil or empty string.

  The param will be passed to `Kernel.to_string()`
  and then `String.trim()` and checked for empty string

  ## Examples

      iex> Malan.Utils.nil_or_empty?("hello")
      false
      iex> Malan.Utils.nil_or_empty?("")
      true
      iex> Malan.Utils.nil_or_empty?(nil)
      true

  """
  def nil_or_empty?(str_or_nil) do
    "" == str_or_nil |> Kernel.to_string() |> String.trim()
  end

  def not_nil_or_empty?(str_or_nil), do: not nil_or_empty?(str_or_nil)

  @doc """
  if `value` (value of the argument) is nil, this will raise `Malan.CantBeNil`

  `argn` (name of the argument) will be passed to allow for more helpful error
  messages that tell you the name of the variable that was `nil`

  ## Examples

      iex> Malan.Utils.raise_if_nil!("somevar", "someval")
      "someval"
      iex> Malan.Utils.raise_if_nil!("somevar", nil)
      ** (Malan.CantBeNil) variable 'somevar' was nil but cannot be
          (malan 0.1.0) lib/malan/utils.ex:135: Malan.Utils.raise_if_nil!/2

  """
  def raise_if_nil!(varname, value) do
    case is_nil(value) do
      true -> raise Malan.CantBeNil, varname: varname
      false -> value
    end
  end

  @doc """
  if `value` (value of the argument) is nil, this will raise `Malan.CantBeNil`

  `argn` (name of the argument) will be passed to allow for more helpful error
  messages that tell you the name of the variable that was `nil`

  ## Examples

      iex> Malan.Utils.raise_if_nil!("someval")
      "someval"
      iex> Malan.Utils.raise_if_nil!(nil)
      ** (Malan.CantBeNil) variable 'somevar' was nil but cannot be
          (malan 0.1.0) lib/malan/utils.ex:142: Malan.Utils.raise_if_nil!/1

  """
  def raise_if_nil!(value) do
    case is_nil(value) do
      true -> raise Malan.CantBeNil
      false -> value
    end
  end

  @doc ~S"""
  Replaces the caracters in `str` with asterisks `"*"`, thus "masking" the value.

  If argument is `nil` nothing will change `nil` will be returned.
  If argument is not a `binary()`, it will be coerced to a binary then masked.
  """
  def mask_str(nil), do: nil
  def mask_str(str) when is_binary(str), do: String.replace(str, ~r/./, "*")
  def mask_str(val), do: Kernel.inspect(val) |> mask_str()

  @doc """
  Convert a list to a `String`, suitable for printing

  Will raise a `String.chars` error if can't coerce part to a `String`

  `mask_keys` is used to mask the values in any keys that are in maps in the `list`
  """
  @spec list_to_string(list :: list() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def list_to_string(list, mask_keys \\ []) do
    list
    |> Enum.map(fn val -> to_string(val, mask_keys) end)
    |> Enum.join(", ")
  end

  @doc """
  Convert a tuple to a `String`, suitable for printing

  Will raise a `String.chars` error if can't coerce part to a `String`

  `mask_keys` is used to mask the values in any keys that are in maps in the `tuple`
  """
  @type tuple_key_value :: binary() | atom()
  @spec tuple_to_string(
          tuple :: {tuple_key_value, tuple_key_value} | String.Chars.t(),
          mask_keys :: list(binary())
        ) ::
          binary()
  def tuple_to_string(tuple, mask_keys \\ [])

  def tuple_to_string({key, value}, mask_keys) do
    # mask value if key is supposed to be masked.  Otherwise pass on
    cond do
      key in list_to_strings_and_atoms(mask_keys) -> {key, mask_str(value)}
      true -> {key, value}
    end
    |> Tuple.to_list()
    |> list_to_string(mask_keys)
  end

  @spec tuple_to_string(tuple :: tuple() | String.Chars.t(), mask_keys :: list(binary())) ::
          binary()
  def tuple_to_string(tuple, mask_keys) do
    tuple
    |> Tuple.to_list()
    |> list_to_string(mask_keys)
  end

  @doc """
  Convert a map to a `String`, suitable for printing.

  Optionally pass a list of keys to mask.

  ## Examples

      iex> map_to_string(%{michael: "knight"})
      "michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"})
      "kitt: 'karr', michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt])
      "kitt: '****', michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt, :michael])
      "kitt: '****', michael: '******'"

      iex> map_to_string(%{"michael" => "knight", "kitt" => "karr", "carr" => "hart"}, ["kitt", "michael"])
      "carr: 'hart', kitt: '****', michael: '******'"

  """
  @spec map_to_string(map :: map() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def map_to_string(map, mask_keys \\ [])

  def map_to_string(%{} = map, mask_keys) do
    Map.to_list(map)
    |> Enum.reverse()
    |> Enum.map(fn {key, val} ->
      case val do
        %{} -> {key, map_to_string(val, mask_keys)}
        l when is_list(l) -> {key, list_to_string(l, mask_keys)}
        t when is_tuple(t) -> {key, tuple_to_string(t, mask_keys)}
        _ -> {key, val}
      end
    end)
    |> Enum.map(fn {key, val} ->
      case key in list_to_strings_and_atoms(mask_keys) do
        true -> {key, mask_str(val)}
        _ -> {key, val}
      end
    end)
    |> Enum.map(fn {key, val} -> "#{key}: '#{val}'" end)
    |> Enum.join(", ")
  end

  def map_to_string(not_a_map, _mask_keys), do: Kernel.to_string(not_a_map)

  def struct_to_string(s, mask_keys \\ []), do: map_to_string(Map.from_struct(s), mask_keys)

  @doc ~S"""
  Convert the value, map, or list to a string, suitable for printing or storing.

  If the value is not a map or list, it must be a type that implements the
  `String.Chars` protocol, otherwise this will fail.

  The reason to offer this util function rather than implementing `String.Chars`
  for maps and lists is that we want to make sure that we never accidentally
  convert those to a string.  This conversion is somewhat destructive and is
  irreversable, so it should only be done intentionally.
  """
  @spec to_string(
          input :: map() | list() | String.Chars.t() | number() | boolean(),
          mask_keys :: list(binary())
        ) ::
          binary()
  def to_string(value, mask_keys \\ [])
  def to_string(%{__struct__: _} = s, mask_keys), do: struct_to_string(s, mask_keys)
  def to_string(%{} = map, mask_keys), do: map_to_string(map, mask_keys)
  def to_string(list, mask_keys) when is_list(list), do: list_to_string(list, mask_keys)
  def to_string(tuple, mask_keys) when is_tuple(tuple), do: tuple_to_string(tuple, mask_keys)
  def to_string(nil, _mask_keys), do: "<nil>"
  def to_string(value, _mask_keys), do: Kernel.to_string(value)

  defp atom_or_string_to_string_or_atom(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp atom_or_string_to_string_or_atom(string) when is_binary(string) do
    String.to_atom(string)
  end

  @doc """
  Takes a list of strings or atoms and returns a list with string and atoms.

  ## Examples

      iex> list_to_strings_and_atoms([:circle])
      [:circle, "circle"]

      iex> list_to_strings_and_atoms([:circle, :square])
      [:square, "square", :circle, "circle"]

      iex> list_to_strings_and_atoms(["circle", "square"])
      ["square", :square, "circle", :circle]
  """
  def list_to_strings_and_atoms(list) do
    Enum.reduce(list, [], fn l, acc -> [l | [atom_or_string_to_string_or_atom(l) | acc]] end)
  end

  @doc ~S"""
  If any of the top-level properties are `Ecto.Association.NotLoaded`, remove them.

  Note that if `map` is actually a `struct` this won't work.  You should first convert
  it to a map:

  ```
  Map.from_struct(struct)
  ```
  """
  def remove_not_loaded(map) do
    Enum.filter(map, fn
      {_k, %Ecto.Association.NotLoaded{} = _v} -> false
      {_k, _v} -> true
    end)
    |> Enum.into(%{})
  end

  def trunc_str(str, length \\ 255), do: String.slice(str, 0, length)

  @doc ~S"""
  If `val` is explicitly (and therefore unambiguously) true, then returns `false`.  Otherwise `true`

  Explicitly true values are case-insensitive, "t", "true", "yes", "y"
  """
  def explicitly_true?(val) when is_binary(val), do: String.downcase(val) in ~w[t true yes y]

  @doc ~S"""
  If `val` is explicitly (and therefore unambiguously) false, then returns `true`.  Otherwise `false`

  Explicitly false values are case-insensitive, "f", "false", "no", "n"
  """
  def explicitly_false?(val) when is_binary(val), do: String.downcase(val) in ~w[f false no n]

  @doc ~S"""
  If `val` is explicitly true, output is true.  Otherwise false

  The effect of this is that if the string isn't explicitly true then it is
  considered false.  This is useful for example with an env var where the default
  should be `false`
  """
  def false_or_explicitly_true?(val) when is_binary(val), do: explicitly_true?(val)
  def false_or_explicitly_true?(val) when is_atom(val), do: val == true

  @doc ~S"""
  If `val` is explicitly false, output is false.  Otherwise true

  The effect of this is that if the string isn't explicitly false then it is
  considered true.  This is useful for example with an env var where the default
  should be `true`
  """
  def true_or_explicitly_false?(val) when is_binary(val), do: not explicitly_false?(val)
  def true_or_explicitly_false?(nil), do: true
  def true_or_explicitly_false?(val) when is_atom(val), do: !!val

  # Derived from `Ecto` library.  Apache 2.0 licensed.
  @typedoc """
  A raw binary representation of a UUID.
  """
  @type uuid_raw :: <<_::128>>

  # Derived from `Ecto` library.  Apache 2.0 licensed.
  @typedoc """
  A hex-encoded UUID string.
  """
  @type uuid :: <<_::288>>

  # Derived from `Ecto` library.  Apache 2.0 licensed.
  @spec bingenerate() :: uuid_raw
  defp bingenerate() do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end

  # Derived from `Ecto` library.  Apache 2.0 licensed.
  @spec encode(uuid_raw) :: uuid
  defp encode(<< a1::4, a2::4, a3::4, a4::4,
                 a5::4, a6::4, a7::4, a8::4,
                 b1::4, b2::4, b3::4, b4::4,
                 c1::4, c2::4, c3::4, c4::4,
                 d1::4, d2::4, d3::4, d4::4,
                 e1::4, e2::4, e3::4, e4::4,
                 e5::4, e6::4, e7::4, e8::4,
                 e9::4, e10::4, e11::4, e12::4 >>) do
    << e(a1), e(a2), e(a3), e(a4), e(a5), e(a6), e(a7), e(a8), ?-,
       e(b1), e(b2), e(b3), e(b4), ?-,
       e(c1), e(c2), e(c3), e(c4), ?-,
       e(d1), e(d2), e(d3), e(d4), ?-,
       e(e1), e(e2), e(e3), e(e4), e(e5), e(e6), e(e7), e(e8), e(e9), e(e10), e(e11), e(e12) >>
  end

  @compile {:inline, e: 1}

  # Derived from `Ecto` library.  Apache 2.0 licensed.
  defp e(0),  do: ?0
  defp e(1),  do: ?1
  defp e(2),  do: ?2
  defp e(3),  do: ?3
  defp e(4),  do: ?4
  defp e(5),  do: ?5
  defp e(6),  do: ?6
  defp e(7),  do: ?7
  defp e(8),  do: ?8
  defp e(9),  do: ?9
  defp e(10), do: ?a
  defp e(11), do: ?b
  defp e(12), do: ?c
  defp e(13), do: ?d
  defp e(14), do: ?e
  defp e(15), do: ?f
end

defmodule Malan.Utils.String do
  @doc """
  Return `true` if the supplied string is empty (whitespace is removed)
  """
  @spec empty?(String.t()) :: boolean()
  def empty?(string) when is_binary(string) do
    string
    |> String.trim()
    |> empty_strict?()
  end

  @doc """
  Return `true` if the supplied string is empty and contains no whitespace
  """
  @spec empty_strict?(String.t()) :: boolean()
  def empty_strict?(string) do
    "" == string
  end
end

defmodule Malan.Utils.Enum do
  @doc """
  will return true if all invocations of the function return false.  If one callback returns `true`, the end result will be `false`

  `Enum.all?` will return true if all invocations of the function return
  true. `Malan.Utils.Enum.none?` is the opposite.
  """
  @spec none?(Enumerable.t(), (any() -> as_boolean(term()))) :: boolean()
  def none?(enumerable, func) do
    Enum.all?(enumerable, fn i -> !func.(i) end)
  end

  @doc """
  will return true if `element` is present in `enumerable`.  See `#Enum.member?/2`
  """
  @spec include?(enumerable :: Enumerable.t(), any()) :: boolean()
  def include?(enumerable, element) do
    Enum.member?(enumerable, element)
  end

  @doc """
  will return true if `element` is present in `enumerable`.  See `#Enum.member?/2`
  """
  @spec includes?(enumerable :: Enumerable.t(), any()) :: boolean()
  def includes?(enumerable, element), do: include?(enumerable, element)

  @doc """
  will return true if `element` is present in `enumerable`.  See `#Enum.member?/2`
  """
  @spec contains?(enumerable :: Enumerable.t(), any()) :: boolean()
  def contains?(enumerable, element), do: include?(enumerable, element)

  @doc ~S"""
  Run `Enum.each/2` for each element in `enumerable`, returning `enumerable` unchanged

  "ident" is short for "identity", like `each_return_identity`
  """
  @spec each_ident(Enumerable.t(), (any() -> any())) :: Enumerable.t()
  def each_ident(enumerable, func) do
    Enum.each(enumerable, func)
    enumerable
  end

  @doc ~S"""
  Invokes `Enum.map/2` on `enumerable` and returns a tuple with {before, after}
  """
  @spec map_add(Enumerable.t(), (Enumerable.element() -> any())) :: [
          {Enumerable.element(), any()}
        ]
  def map_add(enumerable, func) do
    enumerable
    |> Enum.map(fn i -> {i, func.(i)} end)
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
    do: DateTime.truncate(DateTime.utc_now(), :second)

  @doc "Return a DateTime about 200 years into the future"
  def distant_future() do
    round(52.5 * 200 * 7 * 24 * 60 * 60)
    |> adjust_cur_time_trunc(:seconds)
  end

  # New implementation, needs testing
  # def distant_future(),
  #   do: adjust_cur_time(200, :years)

  @doc """
  Add the specified number of units to the current time.

  Supplying a negative number will adjust the time backwards by the
  specified units, while supplying a positive will adjust the time
  forwards by the specified units.
  """
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
    do: adjust_time(DateTime.utc_now(), num_seconds, :seconds)

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

  @doc "Check if `past_time` occurs before `current_time`.  Equal date returns true"
  @spec in_the_past?(DateTime.t(), DateTime.t()) :: boolean()

  def in_the_past?(past_time, current_time),
    do: DateTime.compare(past_time, current_time) != :gt

  @doc "Check if `past_time` occurs before the current time"
  @spec in_the_past?(DateTime.t()) :: boolean()

  def in_the_past?(nil),
    do: raise(ArgumentError, message: "past_time time must not be nil!")

  def in_the_past?(past_time),
    do: in_the_past?(past_time, DateTime.utc_now())

  def expired?(expires_at, current_time),
    do: in_the_past?(expires_at, current_time)

  def expired?(nil),
    do: raise(ArgumentError, message: "expires_at time must not be nil!")

  def expired?(expires_at),
    do: in_the_past?(expires_at, DateTime.utc_now())
end

defmodule Malan.Utils.IPv4 do
  def to_s(%Plug.Conn{} = conn), do: to_s(conn.remote_ip)

  def to_s(ip_tuple) do
    ip_tuple
    |> :inet_parse.ntoa()
    |> Kernel.to_string()
  end
end

defmodule Malan.Utils.Phoenix.Controller do
  import Plug.Conn, only: [halt: 1, put_status: 2]

  require Logger

  def halt_status(conn, status, details \\ %{}) do
    Logger.debug("[halt_status]: status: #{status}")

    conn
    |> put_status(status)
    |> Phoenix.Controller.put_view(MalanWeb.ErrorView)
    |> Phoenix.Controller.render("#{status}.json", details)
    |> halt()
  end

  def remote_ip_s(conn), do: Malan.Utils.IPv4.to_s(conn.remote_ip)
end

defmodule Malan.Utils.Ecto.Query do
  defguard valid_sort(sort) when is_atom(sort) and sort in [:asc, :desc]
end

defmodule Malan.Utils.Ecto.Changeset do
  @doc """
  Validates that the property specified does NOT match the provided regex.

  This function is essentially the opposite of validate_format()
  """
  def validate_not_format(nil, _regex), do: false
  def validate_not_format(value, regex), do: value =~ regex

  def validate_not_format(changeset, property, regex) do
    case validate_not_format(Map.get(changeset.changes, property), regex) do
      true -> Ecto.Changeset.add_error(changeset, property, "has invalid format")
      false -> changeset
    end
  end

  def validate_ip_addr(changeset, property, allow_empty? \\ false) do
    val = Ecto.Changeset.get_change(changeset, property)

    cond do
      allow_empty? && val == "" ->
        changeset

      Iptools.is_ipv4?(val) ->
        changeset

      true ->
        Ecto.Changeset.add_error(
          changeset,
          property,
          "#{property} must be a valid IPv4 or IPv6 address"
        )
    end
  end

  @doc ~S"""
  Convert changeset errors into a list of `String`s

  ## Examples

      Malan.Utils.Ecto.Changeset.errors_to_str_list(changeset)
      # TODO example needs updated
      [who: {"who must be a valid ID of a user", []}]
  """
  def errors_to_str_list(%Ecto.Changeset{errors: errors}),
    do: errors_to_str_list(errors)

  def errors_to_str_list(errors) do
    Enum.map(errors, fn
      {field, {err_msg, _attrs}} -> "#{field}: #{err_msg}"
    end)
  end

  @doc ~S"""
  Convert changeset errors into a `String`

  ## Examples

      Malan.Utils.Ecto.Changeset.errors_to_str_list(changeset)
      # TODO example needs updated
      [who: {"who must be a valid ID of a user", []}]
  """
  def errors_to_str(%Ecto.Changeset{} = changeset) do
    errors_to_str_list(changeset)
    |> Enum.join(", ")
  end

  def errors_to_str(:too_many_requests) do
    "Rate limit exceeded"
  end

  @doc ~S"""
  If any of the top-level keys in `data` are `Ecto.Changeset`s, apply their changes.

  This is not recursive.  It onliy does the top level.  Also changes are applied
  whether they are valid or not, so consider whether that's the behavior you want.
  """
  def convert_changes(%Ecto.Changeset{changes: changes}), do: convert_changes(changes)

  def convert_changes(%{__struct__: struct_type} = data) do
    data
    |> Map.from_struct()
    |> convert_changes(struct_type)
  end

  def convert_changes(%{} = data) do
    data
    |> Enum.map(fn
      {k, %Ecto.Changeset{} = v} ->
        {k, Ecto.Changeset.apply_changes(v)}

      {k, va} when is_list(va) ->
        {k,
         Enum.map(va, fn
           %Ecto.Changeset{} = v -> Ecto.Changeset.apply_changes(v)
           v -> v
         end)}

      {k, v} ->
        {k, v}
    end)
    |> Enum.into(%{})
  end

  def convert_changes(data), do: data

  def convert_changes(data, struct_type) do
    struct(struct_type, convert_changes(data))
  end
end

defmodule Malan.Utils.FromEnv do
  @spec log_str(env :: Macro.Env.t(), :mfa | :func_only) :: String.t()
  def log_str(%Macro.Env{} = env, :mfa), do: "[#{mfa_str(env)}]"
  def log_str(%Macro.Env{} = env, :func_only), do: "[#{func_str(env)}]"

  @spec log_str(env :: Macro.Env.t()) :: String.t()
  def log_str(%Macro.Env{} = env), do: log_str(env, :mfa)

  @spec mfa_str(env :: Macro.Env.t()) :: String.t()
  def mfa_str(%Macro.Env{} = env), do: mod_str(env) <> "." <> func_str(env)

  @spec func_str(env :: Macro.Env.t() | {atom(), integer()}) :: String.t()
  def func_str(nil), do: "<nil>"
  def func_str({func, arity}), do: "##{func}/#{arity}"
  def func_str(%Macro.Env{} = env), do: func_str(env.function)

  @spec mod_str(env :: Macro.Env.t()) :: String.t()
  def mod_str(%Macro.Env{} = env), do: Kernel.to_string(env.module)
end

defmodule Malan.Utils.Logger do
  alias Malan.Utils.LoggerColor

  import Malan.Utils.FromEnv

  require Logger

  def emergency(msg), do: Logger.emergency(msg, ansi_color: LoggerColor.emergency())
  def alert(msg), do: Logger.alert(msg, ansi_color: LoggerColor.alert())
  def critical(msg), do: Logger.critical(msg, ansi_color: LoggerColor.critical())
  def error(msg), do: Logger.error(msg, ansi_color: LoggerColor.error())
  def warning(msg), do: Logger.warning(msg, ansi_color: LoggerColor.warning())
  def notice(msg), do: Logger.notice(msg, ansi_color: LoggerColor.notice())
  def info(msg), do: Logger.info(msg, ansi_color: LoggerColor.info())
  def debug(msg), do: Logger.debug(msg, ansi_color: LoggerColor.debug())
  def trace(msg), do: Logger.debug("[trace]: " <> msg, ansi_color: LoggerColor.trace())

  def emergency(%Macro.Env{} = env, msg), do: emergency(log_str(env, :mfa) <> ": " <> msg)
  def alert(%Macro.Env{} = env, msg), do: alert(log_str(env, :mfa) <> ": " <> msg)
  def critical(%Macro.Env{} = env, msg), do: critical(log_str(env, :mfa) <> ": " <> msg)
  def error(%Macro.Env{} = env, msg), do: error(log_str(env, :mfa) <> ": " <> msg)
  def warning(%Macro.Env{} = env, msg), do: warning(log_str(env, :mfa) <> ": " <> msg)
  def notice(%Macro.Env{} = env, msg), do: notice(log_str(env, :mfa) <> ": " <> msg)
  def info(%Macro.Env{} = env, msg), do: info(log_str(env, :mfa) <> ": " <> msg)
  def debug(%Macro.Env{} = env, msg), do: debug(log_str(env, :mfa) <> ": " <> msg)
  def trace(%Macro.Env{} = env, msg), do: trace(log_str(env, :mfa) <> ": " <> msg)
end

defmodule Malan.Utils.LoggerColor do
  def green, do: :green
  def black, do: :black
  def red, do: :red
  def yellow, do: :yellow
  def blue, do: :blue
  def cyan, do: :cyan
  def white, do: :white

  def emergency, do: red()
  def alert, do: red()
  def critical, do: red()
  def error, do: red()
  def warning, do: yellow()
  def notice, do: yellow()
  def info, do: green()
  def debug, do: cyan()
  def trace, do: blue()
end

defmodule Malan.Utils.Number do
  import Malan.Utils, only: [defp_testable: 2]
  import Number.Delimit

  def default_int_opts(), do: [precision: 0, delimit: ",", separator: "."]
  def default_float_opts(), do: [precision: 2, delimit: ",", separator: "."]
  def default_intl_int_opts(), do: [precision: 0, delimit: ".", separator: ","]
  def default_intl_float_opts(), do: [precision: 2, delimit: ".", separator: ","]

  @spec format(number :: Number.t()) :: String.t()
  def format(number, opts \\ [])
  def format(number, opts) when is_float(number), do: format_us(number, opts)
  def format(number, opts), do: format_us(number, opts)

  @spec format_us(number :: Number.t()) :: String.t()
  def format_us(number, opts \\ [])

  def format_us(number, opts) when is_float(number) do
    number_to_delimited(number, get_float_opts(opts))
  end

  def format_us(number, opts) do
    number_to_delimited(number, get_int_opts(opts))
  end

  @spec format_intl(number :: Number.t()) :: String.t()
  def format_intl(number, opts \\ [])

  def format_intl(number, opts) when is_float(number) do
    number_to_delimited(number, get_intl_float_opts(opts))
  end

  def format_intl(number, opts) do
    number_to_delimited(number, get_intl_int_opts(opts))
  end

  defp_testable get_int_opts(opts), do: Keyword.merge(default_int_opts(), opts)
  defp_testable get_float_opts(opts), do: Keyword.merge(default_float_opts(), opts)
  defp_testable get_intl_int_opts(opts), do: Keyword.merge(default_intl_int_opts(), opts)
  defp_testable get_intl_float_opts(opts), do: Keyword.merge(default_intl_float_opts(), opts)
end
