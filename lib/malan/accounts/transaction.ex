defmodule Malan.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :type, :string
    field :verb, :string
    field :what, :string
    field :when, :utc_datetime
    field :user_id, :binary_id
    field :session_id, :binary_id
    field :who, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:type, :verb, :when, :what])
    |> validate_required([:type, :verb, :when, :what])
  end
end
