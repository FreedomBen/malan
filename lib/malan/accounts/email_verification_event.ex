defmodule Malan.Accounts.EmailVerificationEvent do
  @moduledoc """
  Audit record for every email-verification-related event. The table is
  append-only — rows are never updated or deleted — so we only set
  `inserted_at` via `timestamps(updated_at: false)`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @event_types ~w(
    requested
    verified
    failed_invalid_token
    failed_expired_token
    skipped_already_verified
    failed_rate_limited
    skipped_domain
    skipped_auto_send_disabled
    admin_set
    backfill_unverified
  )

  @derive {Jason.Encoder, except: [:__meta__, :user]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "email_verification_events" do
    field :email, :string
    field :token_hash, :string
    field :event_type, :string
    field :ip, :string
    field :user_agent, :string

    belongs_to :user, Malan.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def event_types, do: @event_types

  def create_changeset(event, attrs) do
    event
    |> cast(attrs, [
      :user_id,
      :email,
      :token_hash,
      :event_type,
      :ip,
      :user_agent
    ])
    |> validate_required([:user_id, :email, :event_type])
    |> validate_inclusion(:event_type, @event_types)
  end
end
