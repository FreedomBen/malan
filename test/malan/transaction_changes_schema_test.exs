defmodule Malan.TransactionChangesSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Utils
  alias Malan.Accounts.{Session, Transaction}

  def session_changeset_fixture(initial_attrs \\ %{}, change_attrs \\ %{}) do
    %Session{location: "location"}
    |> Map.merge(initial_attrs)
    |> Session.create_changeset(
      %{
        expires_in_seconds: 30,
        ip_address: "ip_address"
      }
      |> Map.merge(change_attrs)
    )
  end

  describe "transactions_changes" do
    # test "#from_changeset/2 success" do
    #   changeset = session_changeset_fixture()
    #   tc = Transaction.Changes.from_changeset(changeset)

    #   assert tc.action == changeset.action
    #   assert tc.changes == Map.update!(changeset.changes, :api_token, &Utils.mask_str/1)
    #   assert tc.data == Utils.struct_to_map(changeset.data)
    #   assert tc.data_type == changeset.data.__meta__.source
    #   assert tc.errors == changeset.errors
    #   assert tc.valid? == true
    # end

    test "#map_from_changeset/2 success" do
      changeset = session_changeset_fixture()
      tc = Transaction.Changes.map_from_changeset(changeset)

      assert tc.action == changeset.action
      assert tc.changes == Map.update!(changeset.changes, :api_token, &Utils.mask_str/1)
      assert tc.data == changeset.data |> Utils.struct_to_map() |> Map.delete(:user)
      assert tc.data_type == changeset.data.__meta__.source
      assert tc.errors == changeset.errors
      assert tc.valid? == true
    end

    test "#validate_data_type/1 requires valid data type" do
      cs = session_changeset_fixture(%{}, %{data_type: "hello"})
      cs = Map.update!(cs, :changes, fn c -> Map.put(c, :data_type, "hello") end)
      cs = Transaction.Changes.validate_data_type(cs)
      [err_msg] = errors_on(cs).data_type
      assert err_msg =~ ~r/^data_type is invalid/i
    end
  end
end
