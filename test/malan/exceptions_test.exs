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

  describe "CantBeNil" do
    test "can create and raise exception" do
      # assert_raise Malan.CantBeNil, fn -> Accounts.update end
      assert_raise Malan.CantBeNil, fn ->
        raise Malan.CantBeNil
      end

      assert_raise Malan.CantBeNil, fn ->
        raise Malan.CantBeNil, argv: "argv", argn: "argn"
      end
    end
  end

  describe "Malan.Pagination.PageOutOfBounds" do
    test "can create and raise exception" do
      assert_raise Malan.Pagination.PageOutOfBounds, fn ->
        raise Malan.Pagination.PageOutOfBounds, table: :ohai, page_num: -2, page_size: 1000
      end
    end
  end
end
