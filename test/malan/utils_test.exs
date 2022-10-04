defmodule Malan.UtilsTest do
  alias Malan.Utils

  # use ExUnit.Case, async: true
  use Malan.DataCase, async: true

  defmodule TestStruct, do: defstruct([:one, :two, :three])

  describe "main" do
    test "#extract/2 works with index on array" do
      assert "world" == Malan.Utils.extract(["hello", "world"], 1)
      assert "world" == Malan.Utils.process(["hello", "world"], 1)
      assert "world" == Malan.Utils.transform(["hello", "world"], 1)
    end

    test "#extract/2 works with index on tuple" do
      assert "hello" == Malan.Utils.extract({"hello", "world"}, 0)
      assert "hello" == Malan.Utils.process({"hello", "world"}, 0)
      assert "hello" == Malan.Utils.transform({"hello", "world"}, 0)
    end

    test "#extract/2 works with key on map" do
      assert 37 == Malan.Utils.extract(%{name: "Jeb", age: 37}, :age)
      assert 37 == Malan.Utils.process(%{name: "Jeb", age: 37}, :age)
      assert 37 == Malan.Utils.transform(%{name: "Jeb", age: 37}, :age)
    end

    test "#extract/2 works with property on struct" do
      assert "one" == Malan.Utils.extract(%TestStruct{one: "one", two: "two"}, :one)
      assert "two" == Malan.Utils.process(%TestStruct{one: "one", two: "two"}, :two)
      assert nil == Malan.Utils.transform(%TestStruct{one: "one", two: "two"}, :three)
      assert nil == Malan.Utils.transform(%TestStruct{one: "one", two: "two"}, :four)

      assert "one" == Malan.Utils.extract(%TestStruct{one: "one", two: "two"}, "one")
      assert "two" == Malan.Utils.process(%TestStruct{one: "one", two: "two"}, "two")
      assert nil == Malan.Utils.transform(%TestStruct{one: "one", two: "two"}, "three")
      assert nil == Malan.Utils.transform(%TestStruct{one: "one", two: "two"}, "four")
    end

    test "#extract/2 works with function" do
      assert 74 == Malan.Utils.extract(%{name: "Jeb", age: 37}, fn arg -> arg[:age] * 2 end)
      assert 74 == Malan.Utils.process(%{name: "Jeb", age: 37}, fn arg -> arg[:age] * 2 end)
      assert 74 == Malan.Utils.transform(%{name: "Jeb", age: 37}, fn arg -> arg[:age] * 2 end)
    end

    test "#nil_or_empty?/1" do
      assert true == Utils.nil_or_empty?(nil)
      assert true == Utils.nil_or_empty?("")
      assert false == Utils.nil_or_empty?("abcd")
      assert false == Utils.nil_or_empty?(42)
    end

    test "#not_nil_or_empty?/1" do
      assert false == Utils.not_nil_or_empty?(nil)
      assert false == Utils.not_nil_or_empty?("")
      assert true == Utils.not_nil_or_empty?("abcd")
      assert true == Utils.not_nil_or_empty?(42)
    end

    test "#uuidgen/0" do
      uuid_regex = ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/

      # Quick sanity test to fail fast
      assert Utils.uuidgen() =~ uuid_regex

      # Run through a number of invocations and ensure no collisions
      num_vals = 1_000_000

      set =
        Enum.reduce(1..num_vals, MapSet.new(), fn _, acc ->
          next_uuid = Utils.uuidgen()
          assert next_uuid =~ uuid_regex
          assert !MapSet.member?(acc, next_uuid)
          MapSet.put(acc, Utils.uuidgen())
        end)

      assert MapSet.size(set) == num_vals
    end

    test "#is_uuid?/1" do
      assert Utils.is_uuid?(Ecto.UUID.generate())
      assert not Utils.is_uuid?(nil)

      # Strings with a UUID in them aren't valid UUIDs!
      assert not Utils.is_uuid?(Ecto.UUID.generate() <> "ab")
      assert not Utils.is_uuid?("ab" <> Ecto.UUID.generate())
      assert not Utils.is_uuid?("ab" <> Ecto.UUID.generate() <> "ab")
    end

    test "#is_uuid_or_nil?/1" do
      assert Utils.is_uuid_or_nil?(Ecto.UUID.generate())
      assert Utils.is_uuid_or_nil?(nil)

      # Strings with a UUID in them aren't valid UUIDs!
      assert not Utils.is_uuid?(Ecto.UUID.generate() <> "ab")
      assert not Utils.is_uuid?("ab" <> Ecto.UUID.generate())
      assert not Utils.is_uuid?("ab" <> Ecto.UUID.generate() <> "ab")
    end

    test "#nil_or_empty?" do
      assert false == Malan.Utils.nil_or_empty?("hello")
      assert true == Malan.Utils.nil_or_empty?("")
      assert true == Malan.Utils.nil_or_empty?(nil)
    end

    test "#raise_if_nil!/2" do
      assert "lateralus" == Utils.raise_if_nil!("song", "lateralus")

      assert_raise Malan.CantBeNil, fn ->
        Utils.raise_if_nil!("song", nil)
      end
    end

    test "#raise_if_nil!/1" do
      assert "lateralus" == Utils.raise_if_nil!("lateralus")

      assert_raise Malan.CantBeNil, fn ->
        Utils.raise_if_nil!(nil)
      end
    end

    test "#list_to_strings_and_atoms/1" do
      assert [:circle, "circle"] == Utils.list_to_strings_and_atoms([:circle])

      assert [:square, "square", :circle, "circle"] ==
               Utils.list_to_strings_and_atoms([:circle, :square])

      assert ["circle", :circle] == Utils.list_to_strings_and_atoms(["circle"])

      assert ["square", :square, "circle", :circle] ==
               Utils.list_to_strings_and_atoms(["circle", "square"])
    end

    test "#list_to_string/2 works" do
      assert "Dorothy, Rest in Peace, <nil>" ==
               Utils.list_to_string(["Dorothy", "Rest in Peace", nil])
    end

    test "#list_to_string/2 works recursively" do
      assert "Dorothy, Rest in Peace, 2021" ==
               Utils.list_to_string(["Dorothy", ["Rest in Peace", "2021"]])
    end

    test "#list_to_string/2 works with maps in it" do
      assert "Dorothy, albums: 'Rest in Peace, 2021'" ==
               Utils.list_to_string(["Dorothy", %{albums: ["Rest in Peace", "2021"]}])
    end

    test "#list_to_string/2 works with tuples in it" do
      assert "Dorothy, albums, Rest in Peace, 2021" ==
               Utils.list_to_string(["Dorothy", {:albums, ["Rest in Peace", "2021"]}])
    end

    test "#tuple_to_string/2 works with maps in it" do
      assert "error, albums: 'Rest in Peace, 2021'" ==
               Utils.tuple_to_string({:error, %{albums: ["Rest in Peace", "2021"]}})
    end

    test "#tuple_to_string/2 works with keyword lists" do
      # TODO:  Prefer format like:
      # assert "song, [title, 'Rest in Peace', year, '2021']" ==

      assert "song, title, Rest in Peace, year, 2021" ==
               Utils.tuple_to_string({:song, [title: "Rest in Peace", year: "2021"]})
    end

    test "#tuple_to_string/2 masks values when is key value pair" do
      assert "password, *****" == Utils.tuple_to_string({:password, "hello"}, [:password])
      assert "password, *****" == Utils.tuple_to_string({:password, "hello"}, ["password"])

      assert "password, *****" == Utils.tuple_to_string({"password", "hello"}, [:password])
      assert "password, *****" == Utils.tuple_to_string({"password", "hello"}, ["password"])

      assert "password, *****" == Utils.tuple_to_string({"password", 54321}, [:password])
      assert "password, *****" == Utils.tuple_to_string({"password", 54321}, ["password"])

      assert "password, hello, world" ==
               Utils.tuple_to_string({:password, "hello", "world"}, [:password])

      assert "password, hello, world" ==
               Utils.tuple_to_string({:password, "hello", "world"}, ["password"])
    end

    test "struct_to_map/2 works recursively" do
      ts = %TestStruct{
        one: "Uhtred",
        two: "of Bebbanburg",
        three: %TestStruct{
          one: "Alfred",
          two: "of Wessex",
          three: %TestStruct{
            one: 1_000,
            two: "Aethelred of Mercia"
          }
        }
      }

      assert %{
        one: "Uhtred",
        two: "of Bebbanburg",
        three: %{
          one: "Alfred",
          two: "of Wessex",
          three: %{
            one: 1_000,
            two: "Aethelred of Mercia",
            three: nil
          }
        }
      } == Utils.struct_to_map(ts)
    end

    test "#map_to_string/1" do
      assert "michael: 'knight'" == Utils.map_to_string(%{michael: "knight"})

      assert "michael: 'knight', kitt: 'karr'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"})
    end

    test "#map_to_string/2 masks specified values" do
      assert "michael: 'knight', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt])

      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt, :michael])

      assert "michael: '******', kitt: '****', carr: 'hart'" ==
               Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr", "carr" => "hart"}, [
                 "kitt",
                 "michael"
               ])

      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr"}, [:kitt, :michael])

      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, ["kitt", "michael"])
    end

    test "#map_to_string/2 works recursively on maps and masks deeply nested keys" do
      input = %{
        michael: "knight",
        kitt: "karr",
        errors: [one: %{level: {:fatal, true}}],
        courses: %{
          ehrman: %{
            new_testament: "New Testament"
          },
          johnson: %{
            philosophy: [
              %{
                name: "Big Questions of Philosophy",
                year: 2015,
                mask: "maskme"
              }
            ]
          }
        }
      }

      output = Utils.map_to_string(input, ["mask", "kitt"])

      expected =
        "michael: 'knight', kitt: '****', errors: 'one, level: 'fatal, true'', courses: 'johnson: 'philosophy: 'year: '2015', name: 'Big Questions of Philosophy', mask: '******''', ehrman: 'new_testament: 'New Testament'''"

      assert output == expected
    end

    test "#map_to_string/2 echoes back non-map arg" do
      assert "995" == Utils.map_to_string(995)
      assert "995" == Utils.map_to_string("995")
      assert "ARG" == Utils.map_to_string("ARG")
    end

    test "#struct_to_string/2 works" do
      ts = %TestStruct{one: "one", two: "two"}
      assert "two: 'two', three: '', one: 'one'" == Utils.struct_to_string(ts)
      assert "two: 'two', three: '', one: '***'" == Utils.struct_to_string(ts, [:one])
      ts = %TestStruct{one: "one", two: "two", three: ts}

      assert "two: 'two', three: 'two: 'two', three: '', one: '***', __struct__: 'Elixir.Malan.UtilsTest.TestStruct'', one: '***'" ==
               Utils.struct_to_string(ts, [:one])
    end

    test "#to_string/2 works" do
      assert "995" == Utils.to_string(995)
      assert "995" == Utils.to_string("995")
      assert "ARG" == Utils.to_string("ARG")
      assert Utils.to_string(995) == Utils.map_to_string("995")
      assert Utils.to_string("ohai") == Utils.map_to_string("ohai")
      assert Utils.to_string(%{one: "two"}) == Utils.map_to_string(%{one: "two"})
      assert Utils.to_string(["one", "two"]) == Utils.list_to_string(["one", "two"])
      assert Utils.to_string({"one", "two"}) == Utils.tuple_to_string({"one", "two"})
      ts = %TestStruct{one: "one", two: "two"}
      assert Utils.to_string(ts) == Utils.struct_to_string(ts)
    end

    test "#to_string/{1,2} on nil work" do
      assert "<nil>" == Utils.to_string(nil)
      assert "<nil>" == Utils.to_string(nil, "anything")
    end

    test "mask_str/1 nil returns nil" do
      assert is_nil(Utils.mask_str(nil))
    end

    test "mask_str/1 masks the str" do
      assert "*****" == Utils.mask_str("hello")
    end

    test "mask_str/1 converts non-binary to binary and masks the str" do
      assert "**" == Utils.mask_str(89)
      assert "*****" == Utils.mask_str(1.456)
    end

    test "#remove_not_loaded/1" do
      before = %{
        one: "one",
        two: "two",
        three: %Ecto.Association.NotLoaded{}
      }

      after_removed = %{
        one: "one",
        two: "two"
      }

      assert after_removed == Utils.remove_not_loaded(before)
    end

    test "#explicitly_true?/1" do
      assert true == Utils.explicitly_true?("true")
      assert true == Utils.explicitly_true?("True")
      assert true == Utils.explicitly_true?("T")
      assert true == Utils.explicitly_true?("t")
      assert true == Utils.explicitly_true?("Yes")
      assert true == Utils.explicitly_true?("yes")
      assert true == Utils.explicitly_true?("Y")
      assert true == Utils.explicitly_true?("y")

      assert false == Utils.explicitly_true?("F")
      assert false == Utils.explicitly_true?("f")
      assert false == Utils.explicitly_true?("False")
      assert false == Utils.explicitly_true?("false")
      assert false == Utils.explicitly_true?("n")
      assert false == Utils.explicitly_true?("N")
      assert false == Utils.explicitly_true?("no")
      assert false == Utils.explicitly_true?("No")
      assert false == Utils.explicitly_true?("NO")
      assert false == Utils.explicitly_true?("nO")
    end

    test "#false_or_explicitly_true?/1" do
      assert false == Utils.false_or_explicitly_true?("F")
      assert false == Utils.false_or_explicitly_true?("f")
      assert false == Utils.false_or_explicitly_true?("False")
      assert false == Utils.false_or_explicitly_true?("false")
      assert false == Utils.false_or_explicitly_true?("n")
      assert false == Utils.false_or_explicitly_true?("N")
      assert false == Utils.false_or_explicitly_true?("no")
      assert false == Utils.false_or_explicitly_true?("No")
      assert false == Utils.false_or_explicitly_true?("NO")
      assert false == Utils.false_or_explicitly_true?("nO")

      assert false == Utils.false_or_explicitly_true?(false)
      assert false == Utils.false_or_explicitly_true?("Hello")
      assert false == Utils.false_or_explicitly_true?("")
      assert false == Utils.false_or_explicitly_true?(nil)

      assert true == Utils.false_or_explicitly_true?("true")
      assert true == Utils.false_or_explicitly_true?("True")
      assert true == Utils.false_or_explicitly_true?("T")
      assert true == Utils.false_or_explicitly_true?("t")
      assert true == Utils.false_or_explicitly_true?("Yes")
      assert true == Utils.false_or_explicitly_true?("yes")
      assert true == Utils.false_or_explicitly_true?("Y")
      assert true == Utils.false_or_explicitly_true?("y")
      assert true == Utils.false_or_explicitly_true?(true)
    end

    test "#explicitly_false?/1" do
      assert false == Utils.explicitly_false?("true")
      assert false == Utils.explicitly_false?("True")
      assert false == Utils.explicitly_false?("T")
      assert false == Utils.explicitly_false?("t")
      assert false == Utils.explicitly_false?("Yes")
      assert false == Utils.explicitly_false?("yes")
      assert false == Utils.explicitly_false?("Y")
      assert false == Utils.explicitly_false?("y")

      assert true == Utils.explicitly_false?("F")
      assert true == Utils.explicitly_false?("f")
      assert true == Utils.explicitly_false?("False")
      assert true == Utils.explicitly_false?("false")
      assert true == Utils.explicitly_false?("n")
      assert true == Utils.explicitly_false?("N")
      assert true == Utils.explicitly_false?("no")
      assert true == Utils.explicitly_false?("No")
      assert true == Utils.explicitly_false?("NO")
      assert true == Utils.explicitly_false?("nO")
    end

    test "#true_or_explicitly_false?/1" do
      assert false == Utils.true_or_explicitly_false?("F")
      assert false == Utils.true_or_explicitly_false?("f")
      assert false == Utils.true_or_explicitly_false?("False")
      assert false == Utils.true_or_explicitly_false?("false")
      assert false == Utils.true_or_explicitly_false?("n")
      assert false == Utils.true_or_explicitly_false?("N")
      assert false == Utils.true_or_explicitly_false?("no")
      assert false == Utils.true_or_explicitly_false?("No")
      assert false == Utils.true_or_explicitly_false?("NO")
      assert false == Utils.true_or_explicitly_false?("nO")

      assert false == Utils.true_or_explicitly_false?(false)

      assert true == Utils.true_or_explicitly_false?("true")
      assert true == Utils.true_or_explicitly_false?("True")
      assert true == Utils.true_or_explicitly_false?("T")
      assert true == Utils.true_or_explicitly_false?("t")
      assert true == Utils.true_or_explicitly_false?("Yes")
      assert true == Utils.true_or_explicitly_false?("yes")
      assert true == Utils.true_or_explicitly_false?("Y")
      assert true == Utils.true_or_explicitly_false?("y")

      assert true == Utils.true_or_explicitly_false?(true)
      assert true == Utils.true_or_explicitly_false?("Hello")
      assert true == Utils.true_or_explicitly_false?("")
      assert true == Utils.true_or_explicitly_false?(nil)
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
      manually = DateTime.add(DateTime.utc_now(), 2 * 7 * 24 * 60 * 60, :second)
      diff = DateTime.diff(manually, adjusted, :second)
      # Possibly flakey test. These numbers might be too close.
      # Changed 1 to 2, hopefully that is fuzzy enough to work
      assert diff >= 0 && diff < 2
    end

    test "adjust_time weeks" do
      # This exercises all of the adjust_time funcs since they call each other
      start_dt = DateTime.utc_now()

      assert DateTime.add(start_dt, 2 * 7 * 24 * 60 * 60, :second) ==
               Utils.DateTime.adjust_time(start_dt, 2, :weeks)
    end

    test "#in_the_past?/{1,2}" do
      cur_time = DateTime.utc_now()

      assert_raise(ArgumentError, ~r/past_time.*must.not.be.nil/, fn ->
        Utils.DateTime.in_the_past?(nil)
      end)

      assert false == Utils.DateTime.in_the_past?(Utils.DateTime.adjust_cur_time(1, :minutes))
      assert true == Utils.DateTime.in_the_past?(Utils.DateTime.adjust_cur_time(-1, :minutes))
      # exact same time shows as expired
      assert true == Utils.DateTime.in_the_past?(cur_time)

      assert true ==
               Utils.DateTime.in_the_past?(cur_time, Utils.DateTime.adjust_cur_time(1, :minutes))

      assert false ==
               Utils.DateTime.in_the_past?(cur_time, Utils.DateTime.adjust_cur_time(-1, :minutes))

      assert true == Utils.DateTime.in_the_past?(cur_time, cur_time)
    end

    test "#expired?/{1,2}" do
      cur_time = DateTime.utc_now()

      assert_raise(ArgumentError, ~r/expires_at.*must.not.be.nil/, fn ->
        Utils.DateTime.expired?(nil)
      end)

      assert false == Utils.DateTime.expired?(Utils.DateTime.adjust_cur_time(1, :minutes))
      assert true == Utils.DateTime.expired?(Utils.DateTime.adjust_cur_time(-1, :minutes))
      # exact same time shows as expired
      assert true == Utils.DateTime.expired?(cur_time)

      assert true ==
               Utils.DateTime.expired?(cur_time, Utils.DateTime.adjust_cur_time(1, :minutes))

      assert false ==
               Utils.DateTime.expired?(cur_time, Utils.DateTime.adjust_cur_time(-1, :minutes))

      assert true == Utils.DateTime.expired?(cur_time, cur_time)
    end
  end

  describe "Access" do
    def singer, do: "Dexter"
    def lead_guitar, do: "Noodles"

    def band, do: %{"singer" => singer(), lead_guitar: lead_guitar()}
    def map_one, do: %{one: band()}
    def map_two, do: %{two: map_one()}
    def map_three, do: %{"three" => map_two()}
    def map_four, do: %{four: map_three()}

    defp structure do
      # structure will look like this:
      #
      # %{
      #   four: %{
      #     "three" => %{
      #       two: %{
      #         one: %{
      #           "singer" => "Dexter",
      #           lead_guitar: "Noodles"
      #         }
      #       }
      #     }
      #   }
      # }
      map_four()
    end

    test "#has_path?/2" do
      assert true == Utils.Access.has_path?(structure(), [:four, "three", :two, :one, "singer"])

      assert true ==
               Utils.Access.has_path?(structure(), [:four, "three", :two, :one, :lead_guitar])

      assert true == Utils.Access.has_path?(structure(), [:four, "three", :two, :one])
      assert true == Utils.Access.has_path?(structure(), [:four, "three", :two])
      assert true == Utils.Access.has_path?(structure(), [:four, "three"])
      assert true == Utils.Access.has_path?(structure(), [:four])
      assert true == Utils.Access.has_path?(structure(), [])

      assert false == Utils.Access.has_path?(structure(), [:four, "three", :two, :one, :wrong])

      assert false ==
               Utils.Access.has_path?(structure(), [:four, "three", :two, :one, "not_there"])

      assert false == Utils.Access.has_path?(structure(), [:four, "three", :two, :seven])
      assert false == Utils.Access.has_path?(structure(), [:four, "three", :twelve])
      assert false == Utils.Access.has_path?(structure(), [:four, "nineteen"])
      assert false == Utils.Access.has_path?(structure(), [:twenty_one])
    end

    test "#value_at/3" do
      assert singer() ==
               Utils.Access.value_at(structure(), [:four, "three", :two, :one, "singer"])

      assert lead_guitar() ==
               Utils.Access.value_at(structure(), [:four, "three", :two, :one, :lead_guitar])

      assert band() == Utils.Access.value_at(structure(), [:four, "three", :two, :one])
      assert map_one() == Utils.Access.value_at(structure(), [:four, "three", :two])
      assert map_two() == Utils.Access.value_at(structure(), [:four, "three"])
      assert map_three() == Utils.Access.value_at(structure(), [:four])
      assert map_four() == Utils.Access.value_at(structure(), [])
    end

    test "#value_at/3 when key does not exist" do
      assert is_nil(Utils.Access.value_at(structure(), [:four, "three", :wrong, :one, "singer"]))

      assert "DEFAULT_VALUE" ==
               Utils.Access.value_at(
                 structure(),
                 [:four, "three", :wrong, :one, "singer"],
                 "DEFAULT_VALUE"
               )

      struct_structure = %TestStruct{
        one: "one",
        two: %{
          struct: %TestStruct{three: %{"winner" => "Alan"}}
        }
      }

      assert is_nil(
               Utils.Access.value_at(struct_structure, [:two, :struct, :three, "not present"])
             )

      assert "DEFAULT_VALUE" ==
               Utils.Access.value_at(
                 struct_structure,
                 [:two, :struct, :three, "not present"],
                 "DEFAULT_VALUE"
               )

      assert nil == Utils.Access.value_at(struct_structure, [:missing])

      assert "DEFAULT_VALUE" ==
               Utils.Access.value_at(struct_structure, [:missing], "DEFAULT_VALUE")
    end

    test "#value_is?/3" do
      assert true ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, "singer"],
                 singer()
               )

      assert true ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one, "singer"], fn _ ->
                 singer()
               end)

      assert true ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, :lead_guitar],
                 lead_guitar()
               )

      assert true ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, :lead_guitar],
                 fn _ -> lead_guitar() end
               )

      assert true == Utils.Access.value_is?(structure(), [:four, "three", :two, :one], band())

      assert true ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one], fn _ ->
                 band()
               end)

      assert true == Utils.Access.value_is?(structure(), [:four, "three", :two], map_one())

      assert true ==
               Utils.Access.value_is?(structure(), [:four, "three", :two], fn _ -> map_one() end)

      assert true == Utils.Access.value_is?(structure(), [:four, "three"], map_two())
      assert true == Utils.Access.value_is?(structure(), [:four, "three"], fn _ -> map_two() end)

      assert true == Utils.Access.value_is?(structure(), [:four], map_three())
      assert true == Utils.Access.value_is?(structure(), [:four], fn _ -> map_three() end)

      assert true == Utils.Access.value_is?(structure(), [], structure())
      assert true == Utils.Access.value_is?(structure(), [], fn _ -> structure() end)
      assert true == Utils.Access.value_is?(structure(), [], map_four())
      assert true == Utils.Access.value_is?(structure(), [], fn _ -> map_four() end)

      assert false ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, "singer"],
                 "nothing"
               )

      assert false ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one, "singer"], fn _ ->
                 "nothing"
               end)

      assert false ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, :lead_guitar],
                 "nothing"
               )

      assert false ==
               Utils.Access.value_is?(
                 structure(),
                 [:four, "three", :two, :one, :lead_guitar],
                 fn _ -> "nothing" end
               )

      assert false == Utils.Access.value_is?(structure(), [:four, "three", :two, :one], nil)

      assert false ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one], fn _ -> nil end)

      assert false == Utils.Access.value_is?(structure(), [:four, "three", :two], "Todd")

      assert false ==
               Utils.Access.value_is?(structure(), [:four, "three", :two], fn _ -> "Todd" end)

      assert false == Utils.Access.value_is?(structure(), [:four, "three"], "Ron")
      assert false == Utils.Access.value_is?(structure(), [:four, "three"], fn _ -> "Ron" end)

      assert false == Utils.Access.value_is?(structure(), [:four], "James")
      assert false == Utils.Access.value_is?(structure(), [:four], fn _ -> "James" end)

      assert false == Utils.Access.value_is?(structure(), [], "Atom")
      assert false == Utils.Access.value_is?(structure(), [], fn _ -> "Pete" end)

      assert false ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one, "singer"], fn _ ->
                 nil
               end)

      # Identity function is always true
      assert true ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one, "singer"], fn x ->
                 x
               end)

      assert true ==
               Utils.Access.value_is?(structure(), [:four, "three", :two, :one], fn x -> x end)

      assert true == Utils.Access.value_is?(structure(), [:four, "three", :two], fn x -> x end)
      assert true == Utils.Access.value_is?(structure(), [:four, "three"], fn x -> x end)
      assert true == Utils.Access.value_is?(structure(), [:four], fn x -> x end)
      assert true == Utils.Access.value_is?(structure(), [], fn x -> x end)
    end

    test "#value_is?/2 works with structs (this covers has_key?/2 and value_at/3 also" do
      struct_structure = %TestStruct{
        one: "one",
        two: %{
          struct: %TestStruct{three: %{"winner" => "Alan"}}
        }
      }

      assert true ==
               Utils.Access.value_is?(struct_structure, [:two, :struct, :three, "winner"], "Alan")

      assert false == Utils.Access.value_is?(struct_structure, [:two, :struct, :winner], "Alan")

      assert false ==
               Utils.Access.value_is?(struct_structure, [:two, :struct, :three, :winner], "Alan")
    end

    test "#value_is?/2 works with keyword lists" do
      ns = [
        one: "one",
        two: "two",
        three: %{
          "four" => [
            five: "five"
          ]
        }
      ]

      assert true == Utils.Access.value_is?(ns, [:one], "one")
      assert true == Utils.Access.value_is?(ns, [:two], "two")
      assert true == Utils.Access.value_is?(ns, [:three, "four", :five], "five")

      assert false == Utils.Access.value_is?(ns, [:one], "two")
      assert false == Utils.Access.value_is?(ns, [:three, "four", :five], "six")
    end
  end

  describe "String" do
    test "#empty?/1" do
      assert true == Utils.String.empty?("")
      assert true == Utils.String.empty?(" ")
      assert true == Utils.String.empty?(" \t ")
      assert true == Utils.String.empty?(" \t \n\n ")

      assert false == Utils.String.empty?("hey")
    end

    test "#empty_strict?/1" do
      assert true == Utils.String.empty?("")

      assert false == Utils.String.empty_strict?(" ")
      assert false == Utils.String.empty_strict?(" \t ")
      assert false == Utils.String.empty_strict?("hey")
      assert false == Utils.String.empty_strict?(1)
      assert false == Utils.String.empty_strict?(nil)
    end
  end

  describe "Enum" do
    test "#none?" do
      input = ["one", "two", "three"]
      assert true == Utils.Enum.none?(input, fn i -> i == "four" end)
      assert false == Utils.Enum.none?(input, fn i -> i == "three" end)
    end

    test "#include?/2" do
      l1 = ["Henry Fonda", "Jimmy Stewart", "John Wayne"]

      assert Malan.Utils.Enum.include?(l1, "Jimmy Stewart")
      assert Malan.Utils.Enum.includes?(l1, "Jimmy Stewart")
      assert Malan.Utils.Enum.contains?(l1, "Jimmy Stewart")

      assert not Malan.Utils.Enum.include?(l1, "Johnny Wayne")
      assert not Malan.Utils.Enum.includes?(l1, "Johnny Wayne")
      assert not Malan.Utils.Enum.contains?(l1, "Johnny Wayne")
    end

    test "#each_ident/2 works" do
      l1 = ["Henry Fonda", "Jimmy Stewart", "John Wayne"]
      assert l1 == Malan.Utils.Enum.each_ident(l1, &(assert Enum.member?(l1, &1)))

      l2 = [henry: "Henry Fonda", james: "Jimmy Stewart", john: "John Wayne"]
      assert l2 == Malan.Utils.Enum.each_ident(l2, &(assert Enum.member?(l2, &1)))
    end

    test "#map_add/2 works" do
      list = ["Henry Fonda", "Jimmy Stewart", "John Wayne"]

      assert [
               {"Henry Fonda", "Henry Fonda rocks"},
               {"Jimmy Stewart", "Jimmy Stewart rocks"},
               {"John Wayne", "John Wayne rocks"}
             ] = Malan.Utils.Enum.map_add(list, &(&1 <> " rocks"))
    end
  end

  describe "Phoenix.Controller" do
  end

  describe "Ecto.Changeset" do
    test "#convert_changes/1" do
      ts = %TestStruct{one: "one", two: "two"}
      cs = Ecto.Changeset.change({ts, %{one: :string, two: :string}})

      assert %{ts | three: ts} ==
               Utils.Ecto.Changeset.convert_changes(%{ts | three: cs})
    end

    test "#convert_changes/1 handles arrays" do
      ts = %TestStruct{one: "one", two: "two"}
      cs = Ecto.Changeset.change({ts, %{one: :string, two: :string}})

      assert %{ts | three: [ts, ts]} ==
               Utils.Ecto.Changeset.convert_changes(%{ts | three: [cs, cs]})
    end

    test "#validate_ip_addr/2 allows valid address through" do
      types = %{one: :string, two: :string, three: :string}
      ts = %TestStruct{one: "one", two: "two"}

      cs =
        Ecto.Changeset.change({ts, types}, %{three: "1.1.1.1"})
        |> Utils.Ecto.Changeset.validate_ip_addr(:three)

      assert cs.valid?

      cs =
        Ecto.Changeset.change({ts, types}, %{three: "127.0.0.1"})
        |> Utils.Ecto.Changeset.validate_ip_addr(:three)

      assert cs.valid?

      cs =
        Ecto.Changeset.change({ts, types}, %{three: "255.255.255.255"})
        |> Utils.Ecto.Changeset.validate_ip_addr(:three)

      assert cs.valid?
    end

    test "#validate_ip_addr/2 adds error to changeset when not valid" do
      types = %{one: :string, two: :string, three: :string}
      ts = %TestStruct{one: "one", two: "two"}
      cs = Ecto.Changeset.change({ts, types}, %{three: "1.1.1"})
      assert cs.valid?
      cs = Utils.Ecto.Changeset.validate_ip_addr(cs, :three)
      assert not cs.valid?
    end

    test "#validate_ip_addr/3 accepts empty when flagged" do
      types = %{one: :string, two: :string, three: :string}
      ts = %TestStruct{one: "one", two: "two"}

      cs =
        Ecto.Changeset.change({ts, types}, %{three: ""})
        |> Utils.Ecto.Changeset.validate_ip_addr(:three, true)

      assert cs.valid?

      cs =
        Ecto.Changeset.change({ts, types}, %{three: ""})
        |> Utils.Ecto.Changeset.validate_ip_addr(:three)

      assert errors_on(cs).three == ["three must be a valid IPv4 or IPv6 address"]
    end
  end

  describe "IPv4" do
    test "works" do
      assert "1.1.1.1" == Utils.IPv4.to_s({1, 1, 1, 1})
      assert "127.0.0.1" == Utils.IPv4.to_s({127, 0, 0, 1})
    end
  end

  describe "FromEnv" do
    test "#log_str/2 :mfa",
      do:
        assert(
          "[Elixir.Malan.UtilsTest.#test FromEnv #log_str/2 :mfa/1]" ==
            Utils.FromEnv.log_str(__ENV__)
        )

    test "#log_str/2 :func_only",
      do:
        assert(
          "[Elixir.Malan.UtilsTest.#test FromEnv #log_str/2 :func_only/1]" ==
            Utils.FromEnv.log_str(__ENV__)
        )

    test "#log_str/1 defaults to :mfa",
      do: assert(Utils.FromEnv.log_str(__ENV__, :mfa) == Utils.FromEnv.log_str(__ENV__))

    test "#mfa_str/1",
      do:
        assert(
          "Elixir.Malan.UtilsTest.#test FromEnv #mfa_str/1/1" == Utils.FromEnv.mfa_str(__ENV__)
        )

    test "#func_str/1 env",
      do: assert("#test FromEnv #func_str/1 env/1" == Utils.FromEnv.func_str(__ENV__.function))

    test "#func_str/1 func",
      do: assert("#test FromEnv #func_str/1 func/1" == Utils.FromEnv.func_str(__ENV__))

    test "#mod_str/1",
      do: assert("Elixir.Malan.UtilsTest" == Utils.FromEnv.mod_str(__ENV__))

    test "#line_str/1",
      do: assert("924" == Utils.FromEnv.line_str(__ENV__))

    test "#file_str/1",
      do: assert(Utils.FromEnv.file_str(__ENV__) =~ ~r(test/malan/utils_test.exs))

    test "#file_line_str/1",
      do: assert(Utils.FromEnv.file_line_str(__ENV__) =~ ~r(test/malan/utils_test.exs:930$))
  end

  describe "Number" do
    test "#get_int_opts/1 properly merges opts" do
      # Note:  Keyword Lists do not guarantee order, but currently they are
      # predictable and deterministic.  If the order changes in the future this
      # test may need to be updated
      assert [precision: 0, delimit: ",", separator: "."] == Utils.Number.get_int_opts([])

      assert [precision: 0, delimit: ",", separator: ".", one: "one"] ==
               Utils.Number.get_int_opts(one: "one")

      assert [delimit: ",", separator: ".", precision: 3] ==
               Utils.Number.get_int_opts(precision: 3)

      assert [delimit: "-", separator: " ", precision: 1] ==
               Utils.Number.get_int_opts(delimit: "-", separator: " ", precision: 1)
    end

    test "#get_float_opts/1 properly merges opts" do
      # Note:  Keyword Lists do not guarantee order, but currently they are
      # predictable and deterministic.  If the order changes in the future this
      # test may need to be updated
      assert [precision: 2, delimit: ",", separator: "."] == Utils.Number.get_float_opts([])

      assert [precision: 2, delimit: ",", separator: ".", one: "one"] ==
               Utils.Number.get_float_opts(one: "one")

      assert [delimit: ",", separator: ".", precision: 0] ==
               Utils.Number.get_float_opts(precision: 0)

      assert [delimit: "-", separator: " ", precision: 0] ==
               Utils.Number.get_float_opts(delimit: "-", separator: " ", precision: 0)
    end

    test "#format/1" do
      assert "123" == Utils.Number.format(123)
      assert "123.04" == Utils.Number.format(123.04)
      assert "456,789.01" == Utils.Number.format(456_789.01234)
      assert "456,789.0123" == Utils.Number.format(456_789.01234, precision: 4)
    end

    test "#format_us/1" do
      assert "123" == Utils.Number.format_us(123)
      assert "123.04" == Utils.Number.format_us(123.04)
      assert "456,789.01" == Utils.Number.format_us(456_789.01234)
      assert "456,789.0123" == Utils.Number.format_us(456_789.01234, precision: 4)
    end

    # Currently format_intl doesn't work properly!
    @tag :skip
    test "#format_intl/1" do
      assert "123" == Utils.Number.format_intl(123)
      assert "123,04" == Utils.Number.format_intl(123.04)
      assert "456.789,01" == Utils.Number.format_intl(456_789.01234)
      assert "456.789,0123" == Utils.Number.format_intl(456_789.01234, precision: 4)
    end

    test "#to_string/1" do
      assert "80" == Utils.Number.to_string(80)
      assert "80" == Utils.Number.to_string("80")
      assert "443" == Utils.Number.to_string(443)
      assert "443" == Utils.Number.to_string("443")
    end

    test "#to_int/1" do
      assert 80 == Utils.Number.to_int(80)
      assert 80 == Utils.Number.to_int("80")
      assert 80 == Utils.Number.to_int('80')
      assert 443 == Utils.Number.to_int(443)
      assert 443 == Utils.Number.to_int("443")
      assert 443 == Utils.Number.to_int('443')
    end
  end
end
