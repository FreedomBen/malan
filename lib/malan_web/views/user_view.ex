defmodule MalanWeb.UserView do
  use MalanWeb, :view

  alias Malan.Accounts.User

  alias MalanWeb.UserView
  alias MalanWeb.TosAcceptEventView
  alias MalanWeb.PrivacyPolicyAcceptEventView
  alias MalanWeb.PreferencesView
  alias MalanWeb.AddressView
  alias MalanWeb.PhoneNumberView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: %User{addresses: %Ecto.Association.NotLoaded{}} = user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("show.json", %{user: %User{phone_numbers: %Ecto.Association.NotLoaded{}} = user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  #def render("show.json", %{user: %User{phone_numbers: _} = user}) do
  def render("show.json", %{user: %User{} = user}) do
    %{data: render_one(user, UserView, "user_full.json")}
  end

  #def render("show.json", %{user: user}) do
  #  %{data: render_one(user, UserView, "user.json")}
  #end

  def render("user.json", %{user: user}) do
    # If password is non-nil, it is included.  This is needed for
    # example with returning randomly generated passwords
    %{
      id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      nick_name: user.nick_name,
      password: user.password, # need password when randomly generated
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
        render_many(user.tos_accept_events, TosAcceptEventView, "tos_accept_event.json"),
      privacy_policy_accept_events:
        render_many(
          user.privacy_policy_accept_events,
          PrivacyPolicyAcceptEventView,
          "privacy_policy_accept_event.json"
        ),
      roles: user.roles,
      preferences: render_one(user.preferences, PreferencesView, "preferences.json"),
      custom_attrs: user.custom_attrs
    }
    |> Enum.reject(fn {k, v} -> k == :password && is_nil(v) end)
    |> Enum.into(%{})
  end

  def render("user_full.json", %{user: user}) do
    render("user.json", %{user: user})
    |> Map.put(:addresses, render_many(user.addresses, AddressView, "address.json"))
    |> Map.put(
      :phone_numbers,
      render_many(user.phone_numbers, PhoneNumberView, "phone_number.json")
    )
  end

  def render("whoami.json", %{
        user_id: user_id,
        session_id: session_id,
        user_roles: user_roles,
        expires_at: expires_at,
        tos: tos,
        pp: pp
      }) do
    %{
      data: %{
        user_id: user_id,
        session_id: session_id,
        user_roles: user_roles,
        expires_at: expires_at,
        terms_of_service: tos,
        privacy_policy: pp
      }
    }
  end

  def render("password_reset.json", %{
        password_reset_token: password_reset_token,
        password_reset_token_expires_at: password_reset_token_expires_at
      }) do
    %{
      data: %{
        password_reset_token: password_reset_token,
        password_reset_token_expires_at: password_reset_token_expires_at
      }
    }
  end
end
