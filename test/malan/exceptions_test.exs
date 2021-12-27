defmodule Malan.ExceptionsTest do
  use ExUnit.Case, async: true

  describe "ObjectIsImmutable" do
    test "can create and raise exception" do
      # assert_raise Malan.ObjectIsImmutable, fn -> Accounts.update end
      assert_raise Malan.ObjectIsImmutable, fn ->
        raise Malan.ObjectIsImmutable
      end

      assert_raise Malan.ObjectIsImmutable, fn ->
        raise Malan.ObjectIsImmutable, action: "update", type: "FakeType", id: "someID"
      end
    end
  end
end