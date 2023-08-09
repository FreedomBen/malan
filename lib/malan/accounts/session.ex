defmodule Malan.Accounts.Session do
  use Ecto.Schema

  import Ecto.Changeset
  # import Malan.Utils.Ecto.Changeset, only: [validate_ip_addr: 2]

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
    field :valid_only_for_ip, :boolean, default: false
    # This is not yet used but will be in #78
    field :valid_only_for_approved_ips, :boolean, default: false
    # Absolute limit of extension.  Can never extend session beyond this point
    field :extendable_until, :utc_datetime
    # Longest a session can be extended for on each extension request
    field :max_extension_secs, :integer
    # field :auto_extend, :boolean, default: false
    belongs_to :user, User

    embeds_many :extensions, Extension, on_replace: :raise do
      @derive Jason.Encoder
      field :old_expires_at, :utc_datetime
      field :new_expires_at, :utc_datetime
      field :extended_by_seconds, :integer
      field :extended_by_user, :binary_id
      field :extended_by_session, :binary_id
      timestamps(type: :utc_datetime)
    end

    field :api_token, :string, virtual: true
    field :never_expires, :boolean, virtual: true
    field :expires_in_seconds, :integer, virtual: true
    field :extendable_until_seconds, :integer, virtual: true
    field :extend_by_seconds, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "Being updated by an admin"
  def admin_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :api_token,
      :expires_at,
      :extendable_until,
      :max_extension_secs,
      :authenticated_at,
      :revoked_at,
      :ip_address,
      :location,
      :valid_only_for_ip,
      :valid_only_for_approved_ips
    ])
    |> validate_required([
      :expires_at,
      :extendable_until,
      :max_extension_secs,
      :authenticated_at,
      :ip_address
    ])
  end

  @doc "User login session"
  def create_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :never_expires,
      :expires_in_seconds,
      :extendable_until_seconds,
      :max_extension_secs,
      :ip_address,
      :location,
      :valid_only_for_ip,
      :valid_only_for_approved_ips
    ])
    |> put_api_token()
    |> set_expiration_time()
    |> set_max_extension_time()
    |> validate_max_extension_secs()
    |> put_authenticated_at()
    |> validate_required([
      :api_token_hash,
      :expires_at,
      :extendable_until,
      :max_extension_secs,
      :authenticated_at,
      :ip_address
    ])

    # |> validate_ip_addr(:ip_address)
  end

  @doc "Extend a user session"
  def extend_changeset(session, attrs, authed_ids \\ %{}) do
    session
    |> cast(attrs, [:extend_by_seconds])
    |> validate_extend_by_seconds()
    |> validate_required([:extend_by_seconds])
    |> validate_number(:extend_by_seconds, greater_than_or_equal_to: 0)
    |> put_extension_expiration_time()
    |> record_extension(authed_ids)
  end

  @doc "Revoke user session"
  def revoke_changeset(session, attrs) do
    session
    |> cast(attrs, [:revoked_at])
    |> validate_required([
      :revoked_at,
      :api_token_hash,
      :expires_at,
      :extendable_until,
      :authenticated_at,
      :ip_address
    ])
  end

  def record_extension(changeset, authed_ids) do
    new_extension_records =
      prepend_new_extension_record(changeset, %{
        old_expires_at: changeset.data.expires_at,
        new_expires_at: get_change(changeset, :expires_at),
        extended_by_seconds: get_field(changeset, :extend_by_seconds),
        extended_by_user: Map.get(authed_ids, :authed_user_id, nil),
        extended_by_session: Map.get(authed_ids, :authed_session_id)
      })

    changeset
    |> put_embed(:extensions, new_extension_records)
  end

  defp prepend_new_extension_record(changeset, new_extension = %{}) do
    [new_extension | changeset.data.extensions]
  end

  defp gen_api_token(), do: Utils.Crypto.strong_random_string(65)

  defp put_api_token(changeset) do
    api_token = gen_api_token()

    changeset
    |> put_change(:api_token, api_token)
    |> put_change(:api_token_hash, Utils.Crypto.hash_token(api_token))
  end

  defp put_authenticated_at(changeset) do
    put_change(changeset, :authenticated_at, Utils.DateTime.utc_now_trunc())
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

  # Default entrypoint for changeset pipeline
  defp set_expiration_time(changeset) do
    num_secs = Malan.Config.Session.default_token_expiration_secs()
    # num_secs will be ignored if the changeset overrides the default
    set_expiration_time(changeset, num_secs, :seconds)
  end

  # Actually applies the change
  defp set_max_extension_time(%Ecto.Changeset{} = changeset, %DateTime{} = date_time) do
    put_change(changeset, :extendable_until, date_time)
  end

  # Default entrypoint when the max extension time is specified
  defp set_max_extension_time(%{changes: %{extendable_until_seconds: ex_secs}} = changeset) do
    case ex_secs <= Malan.Config.Session.max_max_extension_secs() do
      true ->
        set_max_extension_time(changeset, Utils.DateTime.adjust_cur_time_trunc(ex_secs, :seconds))

      _ ->
        set_max_extension_time(changeset, get_max_extension_time())
    end
  end

  # Default entrypoint from changeset pipeline when no max extension time is specified
  defp set_max_extension_time(changeset) do
    changeset
    |> put_change(
      :extendable_until_seconds,
      Malan.Config.Session.default_max_extension_time_secs()
    )
    |> set_max_extension_time()
  end

  defp get_max_extension_time() do
    Utils.DateTime.adjust_cur_time_trunc(Malan.Config.Session.max_max_extension_secs(), :seconds)
  end

  # Function currently Unused.  Remove later if not needed
  # defp get_default_max_extension_time() do
  #   Utils.DateTime.adjust_cur_time_trunc(
  #     Malan.Config.Session.default_max_extension_time_secs(),
  #     :seconds
  #   )
  # end

  defp validate_extend_by_seconds(changeset) do
    max_extension_secs = get_field(changeset, :max_extension_secs)

    case changeset do
      %{changes: %{extend_by_seconds: extend_by_seconds}} ->
        # Verify that we aren't exceeding the max_extension_secs that was set when this
        # session was first created.  If we are, use the max value instead.
        cond do
          extend_by_seconds <= max_extension_secs -> changeset
          true -> put_change(changeset, :extend_by_seconds, max_extension_secs)
        end

      _ ->
        # User didn't specify an extension time, so use the default max
        put_change(changeset, :extend_by_seconds, max_extension_secs)
    end
  end

  defp put_extension_expiration_time(changeset) do
    # Assign to variables for clarity (semantic meaning in variable name) and readability below
    max_extension_date =
      case get_field(changeset, :extendable_until) do
        nil -> get_field(changeset, :expires_at)
        extendable_until -> extendable_until
      end

    extend_by_seconds = get_change(changeset, :extend_by_seconds)

    # Verify that we aren't exceeding the max extension time for this session.
    # If we are, then just set the expiration time to the max extension time.
    new_expiration_time = Utils.DateTime.adjust_cur_time_trunc(extend_by_seconds, :seconds)

    new_expiration_time =
      case DateTime.compare(new_expiration_time, max_extension_date) do
        :lt -> new_expiration_time
        :eq -> new_expiration_time
        :gt -> max_extension_date
      end

    set_expiration_time(changeset, new_expiration_time)
  end

  defp validate_max_extension_secs(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{max_extension_secs: _}} ->
        changeset

      _ ->
        put_change(
          changeset,
          :max_extension_secs,
          Malan.Config.Session.default_max_extension_secs()
        )
    end
    |> validate_number(:max_extension_secs, greater_than: 0)
  end
end
