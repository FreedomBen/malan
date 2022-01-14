defmodule Malan.UtilsTest do
  alias Malan.Utils

  use ExUnit.Case, async: true

  describe "main" do
    test "nil_or_empty?/1" do
      assert true == Utils.nil_or_empty?(nil)
      assert true == Utils.nil_or_empty?("")
      assert false == Utils.nil_or_empty?("abcd")
      assert false == Utils.nil_or_empty?(42)
    end

    test "uuidgen/0" do
      assert Utils.uuidgen() =~ ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    end

    test "#is_uuid?/1" do
      assert  Utils.is_uuid?(Ecto.UUID.generate())
      assert !Utils.is_uuid?(nil)
    end

    test "#nil_or_empty?" do
      assert false == Malan.Utils.nil_or_empty?("hello")
      assert true  == Malan.Utils.nil_or_empty?("")
      assert true  == Malan.Utils.nil_or_empty?(nil)
    end

    test "#raise_if_nil!/2" do
      assert "lateralus" == Utils.raise_if_nil!("song",  "lateralus")
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
      assert [:square, "square", :circle, "circle"] == Utils.list_to_strings_and_atoms([:circle, :square])

      assert ["circle", :circle] == Utils.list_to_strings_and_atoms(["circle"])
      assert ["square", :square, "circle", :circle] == Utils.list_to_strings_and_atoms(["circle", "square"])
    end

    test "#map_to_string/1" do
      assert "michael: 'knight'" == Utils.map_to_string(%{michael: "knight"})
      assert "kitt: 'karr', michael: 'knight'" == Utils.map_to_string(%{michael: "knight", kitt: "karr"})
    end

    test "#map_to_string/2 masks specified values" do
      assert "kitt: '****', michael: 'knight'" == Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt])
      assert "kitt: '****', michael: '******'" == Utils.map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt, :michael])
      assert "carr: 'hart', kitt: '****', michael: '******'" == Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr", "carr" => "hart"}, ["kitt", "michael"])

      assert "kitt: '****', michael: '******'" == Utils.map_to_string(%{"michael" => "knight", "kitt" => "karr"}, [:kitt, :michael])
      assert "kitt: '****', michael: '******'" == Utils.map_to_string(%{michael: "knight", kitt: "karr"}, ["kitt", "michael"])
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

    test "expired?" do
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
      assert true  == Utils.Enum.none?(input, fn (i) -> i == "four" end)
      assert false == Utils.Enum.none?(input, fn (i) -> i == "three" end)
    end
  end
end
