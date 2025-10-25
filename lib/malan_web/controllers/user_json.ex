defmodule MalanWeb.UserJSON do
  alias Ecto.Association.NotLoaded
  alias Malan.Accounts.User
  alias MalanWeb.AddressJSON
  alias MalanWeb.PhoneNumberJSON
  alias MalanWeb.PreferencesJSON
  alias MalanWeb.PrivacyPolicyAcceptEventJSON
  alias MalanWeb.TosAcceptEventJSON

  def index(%{code: code, users: users, page_num: page_num, page_size: page_size}) do
    %{
      ok: true,
      code: code,
      data: Enum.map(users, &user_data/1),
      page_num: page_num,
      page_size: page_size
    }
  end

  def show(%{code: code, user: %User{addresses: %NotLoaded{}} = user}) do
    %{ok: true, code: code, data: user_data(user)}
  end

  def show(%{code: code, user: %User{phone_numbers: %NotLoaded{}} = user}) do
    %{ok: true, code: code, data: user_data(user)}
  end

  def show(%{code: code, user: %User{} = user}) do
    %{ok: true, code: code, data: user_full_data(user)}
  end

  def whoami(%{
        code: code,
        user_id: user_id,
        session_id: session_id,
        ip_address: ip_address,
        valid_only_for_ip: valid_only_for_ip,
        user_roles: user_roles,
        expires_at: expires_at,
        tos: tos,
        pp: pp
      }) do
    %{
      ok: true,
      code: code,
      data: %{
        user_id: user_id,
        session_id: session_id,
        ip_address: ip_address,
        valid_only_for_ip: valid_only_for_ip,
        user_roles: user_roles,
        expires_at: expires_at,
        terms_of_service: tos,
        privacy_policy: pp
      }
    }
  end

  def password_reset(%{
        code: code,
        password_reset_token: password_reset_token,
        password_reset_token_expires_at: password_reset_token_expires_at
      }) do
    %{
      ok: true,
      code: code,
      data: %{
        password_reset_token: password_reset_token,
        password_reset_token_expires_at: password_reset_token_expires_at
      }
    }
  end

  defp user_data(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      nick_name: user.nick_name,
      password: user.password,
      email: user.email,
      email_verified: user.email_verified,
      birthday: user.birthday,
      sex: User.Sex.to_s(user.sex_enum),
      gender: User.Gender.to_s(user.gender_enum),
      ethnicity: User.Ethnicity.to_s(user.ethnicity_enum),
      race: User.Race.to_a(user.race_enum),
      weight: user.weight,
      height: user.height,
      latest_tos_accept_ver: user.latest_tos_accept_ver,
      latest_pp_accept_ver: user.latest_pp_accept_ver,
      tos_accepted: user.latest_tos_accept_ver == Malan.Accounts.TermsOfService.current_version(),
      privacy_policy_accepted:
        user.latest_pp_accept_ver == Malan.Accounts.PrivacyPolicy.current_version(),
      tos_accept_events:
        maybe_map_collection(
          user.tos_accept_events,
          &TosAcceptEventJSON.tos_accept_event/1
        ),
      privacy_policy_accept_events:
        maybe_map_collection(
          user.privacy_policy_accept_events,
          &PrivacyPolicyAcceptEventJSON.privacy_policy_accept_event/1
        ),
      roles: user.roles,
      preferences: preference_data(user.preferences),
      custom_attrs: user.custom_attrs,
      locked_at: user.locked_at,
      locked_by: user.locked_by,
      approved_ips: user.approved_ips
    }
    |> Enum.reject(fn {key, value} -> key == :password && is_nil(value) end)
    |> Map.new()
  end

  defp user_full_data(%User{} = user) do
    user_data(user)
    |> Map.put(:addresses, maybe_map_collection(user.addresses, &AddressJSON.address/1))
    |> Map.put(
      :phone_numbers,
      maybe_map_collection(user.phone_numbers, &PhoneNumberJSON.phone_number/1)
    )
  end

  defp maybe_map_collection(%NotLoaded{}, _fun), do: []
  defp maybe_map_collection(nil, _fun), do: []
  defp maybe_map_collection(collection, fun), do: Enum.map(collection, fun)

  defp preference_data(%NotLoaded{}), do: nil
  defp preference_data(preferences), do: PreferencesJSON.preferences(preferences)
end
