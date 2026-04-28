defmodule Malan.LogChangesSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Utils
  alias Malan.Accounts.{Session, User, Log}

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

  defp user_with_credential_hashes do
    %User{
      password_hash: "old_pwd_hash_value",
      password_reset_token_hash: "old_reset_hash_value",
      email_verification_token_hash: "old_verify_hash_value"
    }
  end

  describe "logs_changes" do
    # test "#from_changeset/2 success" do
    #   changeset = session_changeset_fixture()
    #   tc = Log.Changes.from_changeset(changeset)

    #   assert tc.action == changeset.action
    #   assert tc.changes == Map.update!(changeset.changes, :api_token, &Utils.mask_str/1)
    #   assert tc.data == Utils.struct_to_map(changeset.data)
    #   assert tc.data_type == changeset.data.__meta__.source
    #   assert tc.errors == changeset.errors
    #   assert tc.valid? == true
    # end

    test "#map_from_changeset/2 success" do
      changeset = session_changeset_fixture()
      tc = Log.Changes.map_from_changeset(changeset)

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
      cs = Log.Changes.validate_data_type(cs)
      [err_msg] = errors_on(cs).data_type
      assert err_msg =~ ~r/^data_type is invalid/i
    end
  end

  describe "credential redaction" do
    # The blacklist must mask raw credentials AND their stored hashes in
    # both `changes` (the new value) and `data` (the existing record), so
    # neither password change events, reset token generation, nor email
    # verification token generation can persist a usable credential into
    # the audit log.

    test "masks password_hash in changes and data" do
      cs =
        user_with_credential_hashes()
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.put_change(:password_hash, "new_pwd_hash_value")

      tc = Log.Changes.map_from_changeset(cs)

      assert tc.changes[:password_hash] == Utils.mask_str("new_pwd_hash_value")
      assert tc.data[:password_hash] == Utils.mask_str("old_pwd_hash_value")
      refute Enum.any?(Map.values(tc.changes), &(&1 == "new_pwd_hash_value"))
      refute Enum.any?(Map.values(tc.data), &(&1 == "old_pwd_hash_value"))
    end

    test "masks password_reset_token_hash in changes and data" do
      cs =
        user_with_credential_hashes()
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.put_change(:password_reset_token_hash, "new_reset_hash_value")

      tc = Log.Changes.map_from_changeset(cs)

      assert tc.changes[:password_reset_token_hash] == Utils.mask_str("new_reset_hash_value")
      assert tc.data[:password_reset_token_hash] == Utils.mask_str("old_reset_hash_value")
      refute Enum.any?(Map.values(tc.changes), &(&1 == "new_reset_hash_value"))
      refute Enum.any?(Map.values(tc.data), &(&1 == "old_reset_hash_value"))
    end

    test "masks email_verification_token_hash in changes and data" do
      cs =
        user_with_credential_hashes()
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.put_change(:email_verification_token_hash, "new_verify_hash_value")

      tc = Log.Changes.map_from_changeset(cs)

      assert tc.changes[:email_verification_token_hash] ==
               Utils.mask_str("new_verify_hash_value")

      assert tc.data[:email_verification_token_hash] ==
               Utils.mask_str("old_verify_hash_value")

      refute Enum.any?(Map.values(tc.changes), &(&1 == "new_verify_hash_value"))
      refute Enum.any?(Map.values(tc.data), &(&1 == "old_verify_hash_value"))
    end

    test "masks raw password_reset_token and email_verification_token virtual fields in changes" do
      cs =
        %User{}
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.put_change(:password_reset_token, "raw-reset-token-aaa")
        |> Ecto.Changeset.put_change(:email_verification_token, "raw-verify-token-bbb")
        |> Ecto.Changeset.put_change(:password, "raw-password-ccc")

      tc = Log.Changes.map_from_changeset(cs)

      assert tc.changes[:password_reset_token] == Utils.mask_str("raw-reset-token-aaa")
      assert tc.changes[:email_verification_token] == Utils.mask_str("raw-verify-token-bbb")
      assert tc.changes[:password] == Utils.mask_str("raw-password-ccc")
      refute Enum.any?(Map.values(tc.changes), &(&1 == "raw-reset-token-aaa"))
      refute Enum.any?(Map.values(tc.changes), &(&1 == "raw-verify-token-bbb"))
      refute Enum.any?(Map.values(tc.changes), &(&1 == "raw-password-ccc"))
    end
  end
end
