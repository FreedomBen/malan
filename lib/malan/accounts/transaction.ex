defmodule Malan.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :type, :string, null: false         # Enum:  users || sessions
    field :verb, :string, null: false         # Action:  GET || POST || PUT || DELETE
    field :what, :string, null: false         # What was done (Human readable string)
    field :when, :utc_datetime, null: false   # When this change happened (may not match created_at)
    field :user_id, :binary_id, null: true    # User making change (owner of the token that changed something)
    field :session_id, :binary_id, null: true # Session making the change (session ownign the token that changed something)
    field :who, :binary_id, null: false       # Which user was modified/changed/created/etc

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:user_id, :session_id, :who, :type, :verb, :when, :what])
    |> validate_required([:who, :type, :verb, :when, :what])
    |> foreign_key_constraint(:who)
  end
end
