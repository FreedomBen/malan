defmodule Malan.Accounts.TotpBackupCode do
  @moduledoc """
  Single-use TOTP backup code.

  Only `Malan.Utils.Crypto.hash_token/1` of the normalized code is at rest;
  the plaintext is shown exactly once, at generation. Codes are mixed-case
  and case-sensitive (client input is normalized by stripping whitespace and
  hyphens only). `used_at` non-nil marks the code as spent.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "totp_backup_codes" do
    field :code_hash, :string, redact: true
    field :used_at, :utc_datetime
    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(backup_code, attrs) do
    backup_code
    |> cast(attrs, [:code_hash, :user_id])
    |> validate_required([:code_hash, :user_id])
  end
end
