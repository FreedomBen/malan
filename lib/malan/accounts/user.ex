defmodule Malan.Accounts.User do
  @compile if Mix.env == :test, do: :export_all

  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.{Utils, Accounts}
  alias Malan.Accounts.TermsOfService, as: ToS
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Accounts.User

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
    field :last_name, :string
    field :nick_name, :string
    field :deleted_at, :utc_datetime
    field :latest_tos_accept_ver, :integer # nil means rejected
    field :latest_pp_accept_ver, :integer  # nil means rejected
    field :birthday, :utc_datetime         # nil means not specified
    field :weight, :decimal                # nil means not specified
    field :height, :decimal                # nil means not specified
    field :race_enum, {:array, :integer}   # nil means not specified
    field :ethnicity_enum, :integer        # nil means not specified
    field :sex_enum, :integer              # nil means not specified
    field :gender_enum, :integer           # nil means not specified
    field :custom_attrs, :map              # Free form JSON for dependent services to use

    embeds_one :preferences, Accounts.Preference, on_replace: :update

    timestamps(type: :utc_datetime)

    field :accept_tos, :boolean, virtual: true            # accepts current ToS version
    field :accept_privacy_policy, :boolean, virtual: true # accepts current PP version
    field :reset_password, :boolean, virtual: true        # triggers a password reset
    field :sex, :string, virtual: true
    field :gender, :string, virtual: true
    field :race, {:array, :string}, virtual: true
    field :ethnicity, :string, virtual: true

    @primary_key {:id, :binary_id, autogenerate: true}
    embeds_many :tos_accept_events, TosAcceptEvent, on_replace: :raise  do
      field :accept, :boolean # true == accept, false == reject
      field :tos_version, :integer
      field :timestamp, :utc_datetime
    end

    @primary_key {:id, :binary_id, autogenerate: true}
    embeds_many :privacy_policy_accept_events, PrivacyPolicyAcceptEvent, on_replace: :raise  do
      field :accept, :boolean # true == accept, false == reject
      field :privacy_policy_version, :integer
      field :timestamp, :utc_datetime
    end
  end

  @doc false
  def registration_changeset(user, params) do
    user
    |> cast(params, [:username, :email, :password, :first_name, :last_name, :nick_name, :sex, :gender, :race, :ethnicity, :birthday, :weight, :custom_attrs])
    |> put_initial_pass()
    |> put_change(:roles, ["user"])
    |> put_change(:preferences, %{theme: "light"})
    |> validate_common()
  end

  @doc false
  def update_changeset(user, params) do
    user
    |> cast(params, [:password, :accept_tos, :accept_privacy_policy, :nick_name, :sex, :gender, :race, :ethnicity, :birthday, :weight, :height, :custom_attrs])
    |> cast_embed(:preferences)
    |> put_accept_tos()
    |> put_accept_privacy_policy()
    |> validate_common()
  end

  @doc false
  def admin_changeset(user, params) do
    # Note that admins are NOT allowed to accept ToS or Privacy Policy
    # on behalf of users
    user
    |> cast(params, [:email, :username, :password, :first_name, :last_name, :nick_name, :roles, :reset_password, :sex, :gender, :race, :ethnicity, :birthday, :weight, :height, :custom_attrs])
    |> cast_embed(:preferences)
    |> put_reset_pass()
    |> validate_common()
  end

  @doc false
  def delete_changeset(user) do
    # In the future once out of beta, anonymize the data instead of marking it deleted
    user
    |> cast(%{deleted_at: Utils.DateTime.utc_now_trunc()}, [:deleted_at])
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
    |> validate_required([:username, :password_hash, :email, :roles, :preferences, :first_name, :last_name])
  end

  defp validate_roles(changeset) do
    changeset
    |> validate_subset(:roles, ["admin", "user", "moderator"])
  end

  defp validate_username(changeset) do
    changeset
    |> unique_constraint(:username)
    |> validate_length(:username, min: 3, max: 89)
    |> validate_format(:username, ~r/^[@!#$%&'\*\+-\/=?^_`{|}~A-Za-z0-9]{3,89}$/)
  end

  defp validate_email(changeset) do
    changeset
    |> unique_constraint(:email)
    |> validate_length(:email, min: 6, max: 100)
    |> validate_format(:email, ~r/^[!#$%&'*+-\/=?^_`{|}~A-Za-z0-9]{1,64}@[.-A-Za-z0-9]{1,63}\.[A-Za-z]{2,25}$/)
    |> validate_not_format(:email, ~r/@.*@/)
  end

  defp validate_password(%Ecto.Changeset{changes: %{password: _pass}} = changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 100)
    |> put_pass_hash()
  end

  defp validate_password(changeset), do: changeset

  defp new_accept_tos(accept_tos, tos_version) do
    %{
      accept: accept_tos,
      tos_version: tos_version,
      timestamp: Utils.DateTime.utc_now_trunc()
    }
  end

  defp prepend_accept_tos(changeset, %{} = new_tos) do
    [ new_tos | changeset.data.tos_accept_events ]
  end

  defp current_tos_ver(false), do: nil
  defp current_tos_ver(true), do: ToS.current_version()

  defp put_accept_tos(%Ecto.Changeset{changes: %{accept_tos: nil}} = changeset), do: changeset

  defp put_accept_tos(%Ecto.Changeset{changes: %{accept_tos: accept_tos}} = changeset) do
    new_tos_accept_events = prepend_accept_tos(
      changeset, new_accept_tos(accept_tos, ToS.current_version())
    )
    changeset
    |> put_embed(:tos_accept_events, new_tos_accept_events)
    |> put_change(:latest_tos_accept_ver, current_tos_ver(accept_tos))
  end

  defp put_accept_tos(changeset), do: changeset

  defp new_accept_pp(accept_pp, pp_version) do
    %{
      accept: accept_pp,
      privacy_policy_version: pp_version,
      timestamp: Utils.DateTime.utc_now_trunc()
    }
  end

  defp prepend_accept_pp(changeset, %{} = new_pp) do
    [ new_pp | changeset.data.privacy_policy_accept_events ]
  end

  defp current_pp_ver(false), do: nil
  defp current_pp_ver(true), do: PrivacyPolicy.current_version()

  defp put_accept_privacy_policy(%Ecto.Changeset{changes: %{accept_privacy_policy: nil}} = changeset), do: changeset

  defp put_accept_privacy_policy(%Ecto.Changeset{changes: %{accept_privacy_policy: accept_pp}} = changeset) do
    new_pp_accept_events = prepend_accept_pp(
      changeset, new_accept_pp(accept_pp, PrivacyPolicy.current_version())
    )
    changeset
    |> put_embed(:privacy_policy_accept_events, new_pp_accept_events)
    |> put_change(:latest_pp_accept_ver, current_pp_ver(accept_pp))
  end

  defp put_accept_privacy_policy(changeset), do: changeset

  defp validate_not_format(nil, _regex), do: false
  defp validate_not_format(value, regex), do: value =~ regex

  @doc """
  Validates that the property specified does NOT match the provided regex.

  This function is essentially the opposite of validate_format()
  """
  defp validate_not_format(changeset, property, regex) do
    case validate_not_format(Map.get(changeset.changes, property), regex) do
      true  -> Ecto.Changeset.add_error(changeset, property, "has invalid format")
      false -> changeset
    end
  end

  defp gender_to_i(changeset) do
    changeset
    |> get_change(:gender)
    |> User.Gender.to_i()
  end

  defp validate_and_put_gender(changeset) do
    case User.Gender.valid?(get_change(changeset, :gender)) do
      true -> put_change(changeset, :gender_enum, gender_to_i(changeset))
      false -> Ecto.Changeset.add_error(changeset, :gender, "gender is invalid.  Should be one of: '#{User.Gender.valid_values_str()}'")
    end
  end

  defp validate_gender(changeset) do
    case get_change(changeset, :gender) do
      nil -> changeset
      _ -> validate_and_put_gender(changeset)
    end
  end

  defp all_races_valid?(changeset) do
    changeset
    |> get_change(:race)
    |> Enum.all?(fn (r) -> User.Race.valid?(r) end)
  end

  # Map string races to enum ints
  defp race_list(changeset) do
    changeset
    |> get_change(:race)
    |> Enum.map(fn (r) -> User.Race.to_i(r) end)
  end

  defp validate_and_put_races(changeset) do
    cond do
      all_races_valid?(changeset) ->
        put_change(changeset, :race_enum, race_list(changeset))

      true ->
        Ecto.Changeset.add_error(changeset,
          :race,
          "race contains an invalid selection.  Should be one of: '#{User.Race.valid_values_str()}'"
        )
    end
  end

  defp validate_race(changeset) do
    case get_change(changeset, :race) do
      nil -> changeset
      _ -> validate_and_put_races(changeset)
    end
  end

  defp ethnicity_to_i(changeset) do
    changeset
    |> get_change(:ethnicity)
    |> User.Ethnicity.to_i()
  end

  defp validate_and_put_ethnicity(changeset) do
    case User.Ethnicity.valid?(get_change(changeset, :ethnicity)) do
      true -> put_change(changeset, :ethnicity_enum, ethnicity_to_i(changeset))
      false -> Ecto.Changeset.add_error(changeset, :ethnicity, "ethnicity is invalid.  Should be one of: '#{User.Ethnicity.valid_values_str()}'")
    end
  end

  defp validate_ethnicity(changeset) do
    case get_change(changeset, :ethnicity) do
      nil -> changeset
      _ -> validate_and_put_ethnicity(changeset)
    end
  end

  defp sex_to_i(changeset) do
    changeset
    |> get_change(:sex)
    |> User.Sex.to_i()
  end

  defp validate_and_put_sex(changeset) do
    case User.Sex.valid?(get_change(changeset, :sex)) do
      true -> put_change(changeset, :sex_enum, sex_to_i(changeset))
      false -> Ecto.Changeset.add_error(changeset, :sex, "sex is invalid.  Should be one of: '#{User.Sex.valid_values_str()}'")
    end
  end

  defp validate_sex(changeset) do
    case get_change(changeset, :sex) do
      nil -> changeset
      _ -> validate_and_put_sex(changeset)
    end
  end

  defp validate_race(changeset) do
    changeset
  end

  defp validate_birthday(changeset) do
    # TODO
    changeset
  end

  defp validate_weight(changeset) do
    # TODO
    changeset
  end

  defp validate_height(changeset) do
    # TODO
    changeset
  end

  @doc false
  defp put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Utils.Crypto.hash_password(pass))

      _ ->
        changeset
    end
  end

  defp put_random_pass(changeset) do
    put_change(changeset, :password, Utils.Crypto.strong_random_string(10))
  end

  defp put_reset_pass(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{reset_password: true}} -> put_random_pass(changeset)
      _ -> changeset
    end
  end

  defp put_initial_pass(changeset) do
    cond do
      Map.has_key?(changeset.changes, :password) -> changeset
      true -> put_random_pass(changeset)
    end
  end
end
