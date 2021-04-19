defmodule Malan.Accounts.Session do
  @compile if Mix.env == :test, do: :export_all

  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.Accounts.User
  alias Malan.Utils

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sessions" do
    field :api_token_hash, :string
    field :authenticated_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :ip_address, :string
    field :location, :string
    field :revoked_at, :utc_datetime
    belongs_to :user, User

    field :api_token, :string, virtual: true
    field :never_expires, :boolean, virtual: true
    field :expires_in_seconds, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "Being updated by an admin"
  def admin_changeset(session, attrs) do
    session
    |> cast(attrs, [:api_token, :expires_at, :authenticated_at, :revoked_at, :ip_address, :location])
    |> validate_required([:api_token, :expires_at, :authenticated_at, :revoked_at, :ip_address, :location])
  end

  @doc "User login session"
  def create_changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :never_expires, :expires_in_seconds, :ip_address, :location])
    |> put_api_token()
    |> set_expiration_time(1, :weeks)
    |> put_authenticated_at()
    |> validate_required([:api_token_hash, :expires_at, :authenticated_at, :ip_address])
  end

  @doc "Revoke user session"
  def revoke_changeset(session, attrs) do
    session
    |> cast(attrs, [:revoked_at])
    |> validate_required([:revoked_at, :api_token_hash, :expires_at, :authenticated_at, :ip_address])
  end

  defp hash_api_token(api_token) do
    :crypto.hash(:sha256, api_token)
    |> Base.encode64()
  end

  defp gen_api_token(), do: Utils.Crypto.strong_random_string(65)

  defp gen_api_token(changeset) do
    put_change(changeset, :api_token, gen_api_token())
  end

  defp put_api_token(changeset) do
    api_token = gen_api_token()
    changeset
    |> put_change(:api_token, api_token)
    |> put_change(:api_token_hash, hash_api_token(api_token))
  end

  defp put_authenticated_at(changeset) do
    put_change(changeset, :authenticated_at, Utils.DateTime.utc_now_trunc)
  end

  defp set_expiration_time(%Ecto.Changeset{} = changeset, %DateTime{} = date_time) do
    put_change(changeset, :expires_at, date_time)
  end

  defp set_expiration_time(%{changes: %{never_expires: true}} = changeset, _num, _units) do
    set_expiration_time(changeset, Utils.DateTime.distant_future())
  end

  defp set_expiration_time(%{changes: %{expires_in_seconds: seconds}} = changeset, _num, _units) do
    set_expiration_time(
      changeset,
      Utils.DateTime.adjust_cur_time_trunc(seconds, :seconds)
    )
  end

  defp set_expiration_time(changeset, num_seconds, :seconds) do
    set_expiration_time(
      changeset,
      Utils.DateTime.adjust_cur_time_trunc(num_seconds, :seconds)
    )
  end

  defp set_expiration_time(changeset, num_minutes, :minutes) do
    set_expiration_time(changeset, num_minutes * 60, :seconds)
  end

  defp set_expiration_time(changeset, num_hours, :hours) do
    set_expiration_time(changeset, num_hours * 60, :minutes)
  end

  defp set_expiration_time(changeset, num_days, :days) do
    set_expiration_time(changeset, num_days * 24, :hours)
  end

  defp set_expiration_time(changeset, num_weeks, :weeks) do
    set_expiration_time(changeset, num_weeks * 7, :days)
  end
end
