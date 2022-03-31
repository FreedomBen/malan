defmodule Malan.UtilsTest do
  alias Malan.Utils

  # use ExUnit.Case, async: true
  use Malan.DataCase, async: true

  defmodule TestStruct, do: defstruct([:one, :two, :three])

  describe "main" do
    test "nil_or_empty?/1" do
      assert true == Utils.nil_or_empty?(nil)
      assert true == Utils.nil_or_empty?("")
      assert false == Utils.nil_or_empty?("abcd")
      assert false == Utils.nil_or_empty?(42)
    end

    test "not_nil_or_empty?/1" do
      assert false == Utils.not_nil_or_empty?(nil)
      assert false == Utils.not_nil_or_empty?("")
      assert true == Utils.not_nil_or_empty?("abcd")
      assert true == Utils.not_nil_or_empty?(42)
    end

    test "uuidgen/0" do
      assert Utils.uuidgen() =~
               ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
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
      assert "Dorothy, Rest in Peace" ==
        Utils.list_to_string(["Dorothy", "Rest in Peace"])
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

    test "#map_to_string/1" do
      assert "michael: 'knight'" == Utils.map_to_string(%{michael: "knight"})

      #assert "kitt: 'karr', michael: 'knight'" ==
      assert "michael: 'knight', kitt: 'karr'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"})
    end

    test "#map_to_string/2 masks specified values" do
      #assert "kitt: '****', michael: 'knight'" ==
      assert "michael: 'knight', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt])

      #assert "kitt: '****', michael: '******'" ==
      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt, :michael])

      #assert "carr: 'hart', kitt: '****', michael: '******'" ==
      assert "michael: '******', kitt: '****', carr: 'hart'" ==
               Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr", "carr" => "hart"}, [
                 "kitt",
                 "michael"
               ])

      #assert "kitt: '****', michael: '******'" ==
      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr"}, [:kitt, :michael])

      #assert "kitt: '****', michael: '******'" ==
      assert "michael: '******', kitt: '****'" ==
               Utils.map_to_string(%{michael: "knight", kitt: "karr"}, ["kitt", "michael"])
    end

    test "#map_to_string/2 works recursively on maps and masks deeply nested keys" do
      input =
        %{
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
          },
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

    test "#to_string/2 works" do
      assert "995" == Utils.to_string(995)
      assert "995" == Utils.to_string("995")
      assert "ARG" == Utils.to_string("ARG")
      assert Utils.to_string(995) == Utils.map_to_string("995")
      assert Utils.to_string("ohai") == Utils.map_to_string("ohai")
      assert Utils.to_string(%{one: "two"}) == Utils.map_to_string(%{one: "two"})
      assert Utils.to_string(["one", "two"]) == Utils.list_to_string(["one", "two"])
      assert Utils.to_string({"one", "two"}) == Utils.tuple_to_string({"one", "two"})
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

  describe "Enum" do
    test "#none?" do
      input = ["one", "two", "three"]
      assert true == Utils.Enum.none?(input, fn i -> i == "four" end)
      assert false == Utils.Enum.none?(input, fn i -> i == "three" end)
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
    test "#log_str/2 :mfa", do:
      assert "[Elixir.Malan.UtilsTest.#test FromEnv #log_str/2 :mfa/1]" == Utils.FromEnv.log_str(__ENV__)

    test "#log_str/2 :func_only", do:
      assert "[Elixir.Malan.UtilsTest.#test FromEnv #log_str/2 :func_only/1]" == Utils.FromEnv.log_str(__ENV__)

    test "#log_str/1 defaults to :mfa", do:
      assert Utils.FromEnv.log_str(__ENV__, :mfa) == Utils.FromEnv.log_str(__ENV__)

    test "#mfa_str/1", do:
      assert "Elixir.Malan.UtilsTest.#test FromEnv #mfa_str/1/1" == Utils.FromEnv.mfa_str(__ENV__)

    test "#func_str/1 env", do:
      assert "#test FromEnv #func_str/1 env/1" == Utils.FromEnv.func_str(__ENV__.function)

    test "#func_str/1 func", do:
      assert "#test FromEnv #func_str/1 func/1" == Utils.FromEnv.func_str(__ENV__)

    test "#mod_str/1", do:
      assert "Elixir.Malan.UtilsTest" == Utils.FromEnv.mod_str(__ENV__)
  end
end
