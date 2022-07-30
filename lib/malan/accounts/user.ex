defmodule Malan.Accounts.User do
  import Malan.Utils, only: [defp_testable: 2]

  use Ecto.Schema

  import Ecto.Changeset
  import Malan.Utils.Ecto.Changeset

  alias Malan.{Utils, Accounts}
  alias Malan.Accounts.TermsOfService, as: ToS
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Accounts.User

  @derive {Swoosh.Email.Recipient, name: :first_name, address: :email}

  @max_email_size 150
  @max_username_size 150

  @deleted_user_uuid_len 37
  @deleted_user_sentinel "|"
  @deleted_user_sentinel_len 1
  @deleted_user_prefix_length (@deleted_user_uuid_len + @deleted_user_sentinel_len)

  @max_email_length (@max_email_size + @deleted_user_prefix_length)
  @max_username_length (@max_username_size + @deleted_user_prefix_length)

  # @valid_roles ["admin", "user", "moderator"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :email_verified, :utc_datetime
    field :password, :string, virtual: true
    field :password_hash, :string
    field :roles, {:array, :string} # admin, user, or moderator
    field :username, :string
    field :first_name, :string
    field :middle_name, :string
    field :last_name, :string
    field :name_prefix, :string
    field :name_suffix, :string
    field :nick_name, :string
    field :display_name, :string
    field :deleted_at, :utc_datetime
    field :latest_tos_accept_ver, :integer # nil means rejected
    field :latest_pp_accept_ver, :integer  # nil means rejected
    field :birthday, :date                 # nil means not specified
    field :weight, :decimal                # nil means not specified
    field :height, :decimal                # nil means not specified
    field :race_enum, {:array, :integer}   # nil means not specified
    field :ethnicity_enum, :integer        # nil means not specified
    field :sex_enum, :integer              # nil means not specified
    field :gender_enum, :integer           # nil means not specified
    field :custom_attrs, :map              # Free form JSON for dependent services to use
    field :locked_at, :utc_datetime, default: nil  # nil means not locked
    field :locked_by, :binary_id, default: nil
    field :password_reset_token, :string, virtual: true
    field :password_reset_token_hash, :string
    field :password_reset_token_expires_at, :utc_datetime
    field :approved_ips, {:array, :string}, null: false, default: []

    has_many :addresses, Accounts.Address, foreign_key: :user_id
    has_many :phone_numbers, Accounts.PhoneNumber, foreign_key: :user_id
    embeds_one :preferences, Accounts.Preference, on_replace: :update

    timestamps(type: :utc_datetime)

    field :accept_tos, :boolean, virtual: true            # accepts current ToS version
    field :accept_privacy_policy, :boolean, virtual: true # accepts current PP version
    field :reset_password, :boolean, virtual: true        # triggers a password reset
    field :sex, :string, virtual: true
    field :gender, :string, virtual: true
    field :race, {:array, :string}, virtual: true
    field :ethnicity, :string, virtual: true

    embeds_many :tos_accept_events, TosAcceptEvent, on_replace: :raise do
      @derive {Jason.Encoder, except: [:__meta__]}
      # true == accept, false == reject
      field :accept, :boolean
      field :tos_version, :integer
      field :timestamp, :utc_datetime
    end

    embeds_many :privacy_policy_accept_events, PrivacyPolicyAcceptEvent, on_replace: :raise do
      @derive {Jason.Encoder, except: [:__meta__]}
      # true == accept, false == reject
      field :accept, :boolean
      field :privacy_policy_version, :integer
      field :timestamp, :utc_datetime
    end
  end

  @doc false
  def registration_changeset(user, params) do
    user
    |> cast(params, [
      :username,
      :email,
      :password,
      :first_name,
      :last_name,
      :middle_name,
      :name_suffix,
      :name_prefix,
      :display_name,
      :nick_name,
      :sex,
      :gender,
      :race,
      :ethnicity,
      :birthday,
      :weight,
      :custom_attrs,
      :approved_ips
    ])
    |> put_initial_pass()
    |> put_change(:roles, ["user"])
    |> put_initial_preferences() # required or the cast_embed will fail
    |> cast_embed(:preferences, with: &Accounts.Preference.changeset/2)
    |> cast_assoc(:addresses, with: &Accounts.Address.create_changeset_assoc/2)
    |> cast_assoc(:phone_numbers, with: &Accounts.PhoneNumber.create_changeset_assoc/2)
    |> downcase_username()
    |> downcase_email()
    |> validate_common()
  end

  @doc false
  def update_changeset(user, params) do
    user
    |> cast(params, [
      :password,
      :accept_tos,
      :accept_privacy_policy,
      :nick_name,
      :sex,
      :gender,
      :race,
      :ethnicity,
      :birthday,
      :weight,
      :height,
      :custom_attrs,
      :approved_ips
    ])
    |> cast_embed(:preferences, with: &Accounts.Preference.changeset/2)
    |> cast_assoc(:addresses, with: &Accounts.Address.create_changeset_assoc/2)
    |> cast_assoc(:phone_numbers, with: &Accounts.PhoneNumber.create_changeset_assoc/2)
    |> put_accept_tos()
    |> put_accept_privacy_policy()
    |> validate_common()
  end

  @doc false
  def admin_changeset(user, params) do
    # Note that admins are NOT allowed to accept ToS or Privacy Policy
    # on behalf of users
    user
    |> cast(params, [
      :email,
      :username,
      :password,
      :first_name,
      :last_name,
      :middle_name,
      :name_suffix,
      :name_prefix,
      :display_name,
      :nick_name,
      :roles,
      :reset_password,
      :sex,
      :gender,
      :race,
      :ethnicity,
      :birthday,
      :weight,
      :height,
      :custom_attrs,
      :approved_ips
    ])
    |> cast_embed(:preferences, with: &Accounts.Preference.changeset/2)
    |> cast_assoc(:addresses, with: &Accounts.Address.create_changeset_assoc/2)
    |> cast_assoc(:phone_numbers, with: &Accounts.PhoneNumber.create_changeset_assoc/2)
    |> downcase_username()
    |> downcase_email()
    |> put_reset_pass()
    |> validate_common()
  end

  def delete_changeset(user) do
    # In the future once out of beta, anonymize the data instead of marking it deleted
    user
    |> cast(%{deleted_at: Utils.DateTime.utc_now_trunc()}, [:deleted_at])
    |> put_change(:email, val_to_deleted_val(user.email))
    |> put_change(:username, val_to_deleted_val(user.username))
  end

  def lock_changeset(user, locked_by) do
    user
    |> cast(
      %{
        locked_at: Utils.DateTime.utc_now_trunc(),
        locked_by: locked_by
      },
      [:locked_at, :locked_by]
    )
    |> foreign_key_constraint(:locked_by)
  end

  def unlock_changeset(user) do
    user
    |> cast(%{locked_at: nil, locked_by: nil}, [:locked_at, :locked_by])
  end

  def password_reset_create_changeset(user) do
    user
    |> change()
    |> put_password_reset_token()
    |> put_password_reset_token_expires_at()
  end

  @doc false
  def password_reset_clear_changeset(user) do
    user
    |> change()
    |> clear_password_reset_token()
    |> clear_password_reset_token_expires_at()
  end

  @doc false
  def password_reset_rate_limit_changeset(user) do
    user
    |> change()
    |> put_change(:password_reset_token, nil)
  end

  @doc false
  def validate_common(changeset) do
    changeset
    |> validate_required([:username, :email])
    |> validate_username()
    |> validate_email()
    |> validate_password()
    |> validate_roles()
    |> validate_sex()
    |> validate_gender()
    |> validate_race()
    |> validate_ethnicity()
    |> validate_birthday()
    |> validate_weight()
    |> validate_height()
    |> validate_approved_ips()
    |> validate_required([
      :username,
      :password_hash,
      :email,
      :roles,
      :preferences,
      :first_name,
      :last_name
    ])
  end

  defp_testable validate_roles(changeset) do
    changeset
    # |> validate_subset(:roles, @valid_roles)
  end

  defp_testable validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: @max_username_length)
    |> validate_format(:username, ~r/^[@!#$%&'\*\+-\/=?^_`{|}~A-Za-z0-9]{3,89}$/)
    |> validate_not_format(:username, ~r/^\|/)  # Doesn't start with a pipe |
    |> unique_constraint(:username)
  end

  defp_testable validate_email(changeset) do
    changeset
    |> validate_length(:email, min: 6, max: @max_email_length)
    |> validate_format(
      :email,
      ~r/^[!#$%&'*+-\/=?^_`{|}~A-Za-z0-9]{1,64}@[.-A-Za-z0-9]{1,63}\.[A-Za-z]{2,25}$/
    )
    |> validate_not_format(:email, ~r/@.*@/)  # Doesn't have more than one @
    |> validate_not_format(:email, ~r/^\|/)   # Doesn't start with a pipe |
    |> unique_constraint(:email)
  end

  defp_testable validate_password(%Ecto.Changeset{changes: %{password: _pass}} = changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 100)
    |> put_pass_hash()
  end

  defp_testable validate_password(changeset) do
    changeset
  end

  defp_testable new_accept_tos(accept_tos, tos_version) do
    %{
      accept: accept_tos,
      tos_version: tos_version,
      timestamp: Utils.DateTime.utc_now_trunc()
    }
  end

  defp_testable prepend_accept_tos(changeset, %{} = new_tos) do
    [new_tos | changeset.data.tos_accept_events]
  end

  defp_testable current_tos_ver(false) do
    nil
  end

  defp_testable current_tos_ver(true) do
    ToS.current_version()
  end

  defp_testable put_accept_tos(%Ecto.Changeset{changes: %{accept_tos: nil}} = changeset) do
    changeset
  end

  defp_testable put_accept_tos(%Ecto.Changeset{changes: %{accept_tos: accept_tos}} = changeset) do
    new_tos_accept_events =
      prepend_accept_tos(
        changeset,
        new_accept_tos(accept_tos, ToS.current_version())
      )

    changeset
    |> put_embed(:tos_accept_events, new_tos_accept_events)
    |> put_change(:latest_tos_accept_ver, current_tos_ver(accept_tos))
  end

  defp_testable put_accept_tos(changeset) do
    changeset
  end

  defp_testable new_accept_pp(accept_pp, pp_version) do
    %{
      accept: accept_pp,
      privacy_policy_version: pp_version,
      timestamp: Utils.DateTime.utc_now_trunc()
    }
  end

  defp_testable prepend_accept_pp(changeset, %{} = new_pp) do
    [new_pp | changeset.data.privacy_policy_accept_events]
  end

  defp_testable current_pp_ver(false) do
    nil
  end

  defp_testable current_pp_ver(true) do
    PrivacyPolicy.current_version()
  end

  defp_testable put_accept_privacy_policy(
                  %Ecto.Changeset{changes: %{accept_privacy_policy: nil}} = changeset
                ) do
    changeset
  end

  defp_testable put_accept_privacy_policy(
                  %Ecto.Changeset{changes: %{accept_privacy_policy: accept_pp}} = changeset
                ) do
    new_pp_accept_events =
      prepend_accept_pp(
        changeset,
        new_accept_pp(accept_pp, PrivacyPolicy.current_version())
      )

    changeset
    |> put_embed(:privacy_policy_accept_events, new_pp_accept_events)
    |> put_change(:latest_pp_accept_ver, current_pp_ver(accept_pp))
  end

  defp_testable put_accept_privacy_policy(changeset) do
    changeset
  end

  defp_testable gender_to_i(changeset) do
    changeset
    |> get_change(:gender)
    |> User.Gender.to_i()
  end

  defp_testable validate_and_put_gender(changeset) do
    case User.Gender.valid?(get_change(changeset, :gender)) do
      true ->
        put_change(changeset, :gender_enum, gender_to_i(changeset))

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :gender,
          "gender is invalid.  Should be one of: '#{User.Gender.valid_values_str()}'"
        )
    end
  end

  defp_testable validate_gender(changeset) do
    case get_change(changeset, :gender) do
      nil -> changeset
      _ -> validate_and_put_gender(changeset)
    end
  end

  defp_testable all_races_valid?(changeset) do
    changeset
    |> get_change(:race)
    |> Enum.all?(fn r -> User.Race.valid?(r) end)
  end

  # Map string races to enum ints
  defp_testable race_list(changeset) do
    changeset
    |> get_change(:race)
    |> Enum.map(fn r -> User.Race.to_i(r) end)
  end

  defp_testable validate_and_put_races(changeset) do
    cond do
      all_races_valid?(changeset) ->
        put_change(changeset, :race_enum, race_list(changeset))

      true ->
        Ecto.Changeset.add_error(
          changeset,
          :race,
          "race contains an invalid selection.  Should be one of: '#{User.Race.valid_values_str()}'"
        )
    end
  end

  defp_testable validate_race(changeset) do
    case get_change(changeset, :race) do
      nil -> changeset
      _ -> validate_and_put_races(changeset)
    end
  end

  defp_testable all_ips_valid?(changeset) do
    changeset
    |> get_change(:approved_ips)
    |> Enum.all?(fn ip -> Iptools.is_ipv4?(ip) end)
  end

  defp_testable validate_and_put_approved_ips(changeset) do
    cond do
      all_ips_valid?(changeset) ->
        changeset

      true ->
        Ecto.Changeset.add_error(
          changeset,
          :approved_ips,
          "approved_ips contains an invalid selection.  Should be valid IPv4 or IPv6 address"
        )
    end
  end

  defp validate_approved_ips(changeset) do
    case get_change(changeset, :approved_ips) do
      nil -> changeset
      _ -> validate_and_put_approved_ips(changeset)
    end
  end

  defp_testable ethnicity_to_i(changeset) do
    changeset
    |> get_change(:ethnicity)
    |> User.Ethnicity.to_i()
  end

  defp_testable validate_and_put_ethnicity(changeset) do
    case User.Ethnicity.valid?(get_change(changeset, :ethnicity)) do
      true ->
        put_change(changeset, :ethnicity_enum, ethnicity_to_i(changeset))

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :ethnicity,
          "ethnicity is invalid.  Should be one of: '#{User.Ethnicity.valid_values_str()}'"
        )
    end
  end

  defp_testable validate_ethnicity(changeset) do
    case get_change(changeset, :ethnicity) do
      nil -> changeset
      _ -> validate_and_put_ethnicity(changeset)
    end
  end

  defp_testable sex_to_i(changeset) do
    changeset
    |> get_change(:sex)
    |> User.Sex.to_i()
  end

  defp_testable validate_and_put_sex(changeset) do
    case User.Sex.valid?(get_change(changeset, :sex)) do
      true ->
        put_change(changeset, :sex_enum, sex_to_i(changeset))

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :sex,
          "sex is invalid.  Should be one of: '#{User.Sex.valid_values_str()}'"
        )
    end
  end

  defp_testable validate_sex(changeset) do
    case get_change(changeset, :sex) do
      nil -> changeset
      _ -> validate_and_put_sex(changeset)
    end
  end

  defp_testable validate_birthday(changeset) do
    # TODO
    changeset
  end

  defp_testable validate_weight(changeset) do
    # TODO
    changeset
  end

  defp_testable validate_height(changeset) do
    # TODO
    changeset
  end

  @doc false
  defp_testable put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Utils.Crypto.hash_password(pass))

      _ ->
        changeset
    end
  end

  defp_testable put_random_pass(changeset) do
    put_change(changeset, :password, Utils.Crypto.strong_random_string(10))
  end

  defp_testable put_reset_pass(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{reset_password: true}} -> put_random_pass(changeset)
      _ -> changeset
    end
  end

  defp_testable put_initial_pass(changeset) do
    cond do
      Map.has_key?(changeset.changes, :password) -> changeset
      true -> put_random_pass(changeset)
    end
  end

  defp_testable gen_reset_token() do
    Utils.Crypto.strong_random_string(65)
  end

  defp_testable put_password_reset_token(changeset) do
    reset_token = gen_reset_token()

    changeset
    |> put_change(:password_reset_token, reset_token)
    |> put_change(:password_reset_token_hash, Utils.Crypto.hash_token(reset_token))
  end

  defp_testable clear_password_reset_token(changeset) do
    changeset
    |> put_change(:password_reset_token, nil)
    |> put_change(:password_reset_token_hash, nil)
  end

  defp_testable put_password_reset_token_expires_at(changeset) do
    changeset
    |> put_change(:password_reset_token_expires_at, get_password_reset_token_expiration_time())
  end

  defp_testable clear_password_reset_token_expires_at(changeset) do
    changeset
    |> put_change(:password_reset_token_expires_at, nil)
  end

  defp_testable get_password_reset_token_expiration_time do
    Malan.Config.User.default_password_reset_token_expiration_secs()
    |> Utils.DateTime.adjust_cur_time_trunc(:seconds)
  end

  defp_testable downcase_username(%Ecto.Changeset{changes: %{username: username}} = cs) do
    put_change(cs, :username, String.downcase(username))
  end

  defp_testable downcase_username(changeset) do
    changeset
  end

  defp_testable downcase_email(%Ecto.Changeset{changes: %{email: email}} = cs) do
    put_change(cs, :email, String.downcase(email))
  end

  defp_testable downcase_email(changeset) do
    changeset
  end

  defp_testable put_initial_preferences(changeset) do
    case get_field(changeset, :preferences) do
      nil -> put_change(changeset, :preferences, %{})
      _ -> changeset
    end
  end

  defp_testable val_to_deleted_val(val) do
    Utils.uuidgen() <> @deleted_user_sentinel <> val
  end

  defp_testable deleted_val_to_val(deleted_val) do
    deleted_val
    |> String.slice((@deleted_user_prefix_length - 1)..String.length(deleted_val))
  end
end
