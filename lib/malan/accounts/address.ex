defmodule Malan.Accounts.Address do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :user]}
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
    field :verified_at, :utc_datetime, default: nil
    # field :user_id, :binary_id
    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(address, attrs) do
    address
    |> cast(attrs, [:primary, :name, :line_1, :line_2, :country, :city, :state, :postal, :user_id])
    |> validate_required([:name, :line_1, :line_2, :country, :city, :state, :postal, :user_id])
  end

  @doc false
  def create_changeset_assoc(address, attrs) do
    address
    |> cast(attrs, [:primary, :name, :line_1, :line_2, :country, :city, :state, :postal])
    |> validate_required([:name, :line_1, :line_2, :country, :city, :state, :postal])
  end

  @doc false
  def update_changeset(address, attrs) do
    address
    |> cast(attrs, [:primary, :name, :line_1, :line_2, :country, :city, :state, :postal])
    |> validate_required([:name, :line_1, :line_2, :country, :city, :state, :postal, :user_id])
  end

  @doc false
  def verify_changeset(address, attrs) do
    address
    |> cast(attrs, [:verified_at])
    |> validate_required([
      :verified_at,
      :name,
      :line_1,
      :line_2,
      :country,
      :city,
      :state,
      :postal,
      :user_id
    ])
  end
end
