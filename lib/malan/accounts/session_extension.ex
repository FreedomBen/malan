defmodule Malan.Accounts.SessionExtension do
  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.Accounts.{Session, User}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "session_extensions" do
    field :new_expires_at, :utc_datetime
    field :old_expires_at, :utc_datetime
    field :extended_by_seconds, :integer
    field :extended_by_user, :binary_id
    field :extended_by_session, :binary_id
    # field :user_id, :binary_id
    # field :session_id, :binary_id
    belongs_to :user, User
    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  def create_changeset(session_changeset = %Ecto.Changeset{}, authed_ids) do
    changeset(%__MODULE__{}, %{
      user_id: get_field(session_changeset, :user_id),
      session_id: get_field(session_changeset, :id),
      old_expires_at: session_changeset.data.expires_at,
      new_expires_at: get_field(session_changeset, :expires_at),
      extended_by_seconds: get_field(session_changeset, :expire_in_seconds),
      extended_by_user: Map.get(authed_ids, :authed_user_id, nil),
      extended_by_session: Map.get(authed_ids, :authed_session_id, nil)
    })
  end

  @doc false
  def changeset(session_extension, attrs) do
    session_extension
    |> cast(attrs, [
      :old_expires_at,
      :new_expires_at,
      :extended_by_seconds,
      :user_id,
      :session_id,
      :extended_by_user,
      :extended_by_session
    ])
    |> validate_required([
      :old_expires_at,
      :new_expires_at,
      :user_id,
      :session_id,
      :extended_by_seconds
    ])
  end
end
