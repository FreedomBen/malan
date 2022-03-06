defmodule Malan.Accounts.Transaction do
  import Malan.Utils, only: [defp_testable: 2]

  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.Utils
  alias Malan.Accounts.Transaction
  alias Malan.Accounts.Transaction.Changes

  @dummy_ip "255.255.255.255"

  def dummy_ip, do: @dummy_ip

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :success, :boolean, null: false     # Was the operation successful?
    field :type_enum, :integer, null: false   # Enum:  users || sessions
    field :verb_enum, :integer, null: false   # Action:  GET || POST || PUT || DELETE
    field :what, :string, null: false         # What was done (Human readable string)
    field :when, :utc_datetime, null: false   # When this change happened (may not match created_at)
    field :user_id, :binary_id, null: true    # User making change (owner of the token that changed something)
    field :session_id, :binary_id, null: true # Session making the change (session owning the token that changed something)
    field :who, :binary_id, null: true        # Which user was modified/changed/created/etc
    field :who_username, :string, null: true  # Which user was modified/changed/created/etc
    field :remote_ip, :string, null: false    # Remote IP of user who did this thing

    # Important Note:  This is often not the exact changeset that was involved,
    # particularly in the case of a successful change.  It will take some
    # refactoring to make that happen.  When successful, the changesets
    # here are often very similar (same field values except for ttimetampes) 
    # but not identical.  With error changesets most of them are identical
    # If applicable, the changeset involved
    embeds_one :changeset, Transaction.Changes, on_replace: :update

    field :type, :string, virtual: true
    field :verb, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(transaction, %{"changeset" => %Ecto.Changeset{}} = attrs) do
    create_changeset(
      transaction,
      Map.update!(attrs, "changeset", fn cs -> Changes.map_from_changeset(cs) end)
    )
  end

  @doc false
  def create_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :success,
      :user_id,
      :session_id,
      :who,
      :who_username,
      :type,
      :verb,
      :when,
      :what,
      :remote_ip
    ])
    |> cast_embed(:changeset, with: &Transaction.Changes.changeset/2)
    |> put_default_when()
    |> validate_required([:success, :type, :verb, :when, :what, :remote_ip])
    |> validate_type()
    |> validate_verb()
    |> validate_who_is_binary_id_or_nil()
    |> validate_remote_ip()
    |> validate_required([:success, :type_enum, :verb_enum, :when, :what, :remote_ip])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:who)
  end

  defp_testable put_default_when(changeset) do
    case get_change(changeset, :when, nil) do
      nil -> put_change(changeset, :when, Utils.DateTime.utc_now_trunc())
      _ -> changeset
    end
  end

  defp_testable validate_type(changeset) do
    case get_change(changeset, :type, nil) do
      nil -> changeset
      _ -> validate_and_put_type(changeset)
    end
  end

  defp_testable validate_and_put_type(changeset) do
    case Transaction.Type.valid?(get_change(changeset, :type, nil)) do
      true ->
        put_change(changeset, :type_enum, type_to_i(changeset))

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :type,
          "type is invalid.  Should be one of: '#{Transaction.Type.valid_values_str()}'"
        )
    end
  end

  defp_testable type_to_i(changeset) do
    changeset
    |> get_change(:type, nil)
    |> Transaction.Type.to_i()
  end

  defp_testable validate_verb(changeset) do
    case get_change(changeset, :verb, nil) do
      nil -> changeset
      _ -> validate_and_put_verb(changeset)
    end
  end

  defp_testable validate_and_put_verb(changeset) do
    case Transaction.Verb.valid?(get_change(changeset, :verb, nil)) do
      true ->
        put_change(changeset, :verb_enum, verb_to_i(changeset))

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :verb,
          "verb is invalid.  Should be one of: '#{Transaction.Verb.valid_values_str()}'"
        )
    end
  end

  defp_testable verb_to_i(changeset) do
    changeset
    |> get_change(:verb, nil)
    |> Transaction.Verb.to_i()
  end

  defp_testable validate_who_is_binary_id_or_nil(changeset) do
    case Utils.is_uuid_or_nil?(get_change(changeset, :who)) do
      true -> changeset
      false -> add_error(changeset, :who, "who must be a valid ID of a user")
    end
  end

  defp_testable validate_remote_ip(changeset) do
    case Iptools.is_ipv4?(get_change(changeset, :remote_ip)) do
      true -> changeset
      false -> add_error(changeset, :remote_ip, "remote_ip must be valid IPv4 address")
    end
  end
end
