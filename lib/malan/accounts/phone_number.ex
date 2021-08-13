defmodule Malan.Accounts.PhoneNumber do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "phone_numbers" do
    field :number, :string
    field :primary, :boolean, default: false
    field :verified, :utc_datetime, default: nil
    #field :user_id, :binary_id
    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:primary, :number, :verified])
    |> validate_required([:primary, :number, :verified, :user_id])
  end
end
