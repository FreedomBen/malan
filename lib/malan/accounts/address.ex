defmodule Malan.Accounts.Address do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "addresses" do
    field :city, :string
    field :country, :string
    field :line_1, :string
    field :line_2, :string
    field :name, :string
    field :postal, :string
    field :primary, :boolean, default: false
    field :state, :string
    field :verified_at, :utc_datetime
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(address, attrs) do
    address
    |> cast(attrs, [:primary, :verified_at, :name, :line_1, :line_2, :country, :city, :state, :postal])
    |> validate_required([:primary, :verified_at, :name, :line_1, :line_2, :country, :city, :state, :postal])
  end
end
