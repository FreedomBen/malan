defmodule Malan.Accounts.UserTotp do
  @moduledoc """
  TOTP (RFC 6238) enrollment for a user. One row per user.

  `secret` is the NimbleTOTP secret encrypted by `Malan.Accounts.TotpCipher`
  under the keyring entry recorded in `key_id`. `confirmed_at` nil means the
  enrollment is pending and inert — it grants nothing and enforces nothing
  until the user confirms possession of the authenticator.

  `last_used_ts` is the Unix-second **start** of the last accepted TOTP step
  (step-aligned, `div(t, 30) * 30`) and serves as the replay-protection
  compare-and-set target. It is nil until enrollment confirmation seeds it.

  No `Jason.Encoder` is derived on purpose: this row must never serialize
  into a response or log wholesale.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_totps" do
    field :secret, :binary, redact: true
    field :key_id, :integer
    field :confirmed_at, :utc_datetime
    field :last_used_ts, :integer
    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(user_totp, attrs) do
    user_totp
    |> cast(attrs, [:secret, :key_id, :user_id])
    |> validate_required([:secret, :key_id, :user_id])
    |> unique_constraint(:user_id)
  end

  @doc false
  def confirm_changeset(user_totp, attrs) do
    user_totp
    |> cast(attrs, [:confirmed_at, :last_used_ts])
    |> validate_required([:confirmed_at, :last_used_ts])
  end
end
