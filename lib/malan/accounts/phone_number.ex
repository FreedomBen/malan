defmodule Malan.Accounts.PhoneNumber do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "phone_numbers" do
    field :number, :string
    field :primary, :boolean, default: false
    field :verified_at, :utc_datetime, default: nil
    #field :user_id, :binary_id
    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:primary, :number, :user_id])
    |> validate_required([:number, :user_id])
  end

  @doc false
  def create_changeset_assoc(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:primary, :number])
    |> validate_required([:number])
  end

  @doc false
  def update_changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:primary, :number])
    |> validate_required([:number, :user_id])
  end

  @doc false
  def verify_changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:verified_at])
    |> validate_required([:number, :user_id])
  end
end
