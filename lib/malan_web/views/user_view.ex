defmodule MalanWeb.UserView do
  use MalanWeb, :view

  alias Malan.Accounts.User

  alias MalanWeb.UserView
  alias MalanWeb.TosAcceptEventView
  alias MalanWeb.PrivacyPolicyAcceptEventView
  alias MalanWeb.PreferencesView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    # If password is non-nil, it is included.  This is needed for
    # example with returning randomly generated passwords
    %{id: user.id,
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
      privacy_policy_accepted: user.latest_pp_accept_ver == Malan.Accounts.PrivacyPolicy.current_version(),
      tos_accept_events: render_many(user.tos_accept_events, TosAcceptEventView, "tos_accept_event.json"),
      privacy_policy_accept_events: render_many(user.privacy_policy_accept_events, PrivacyPolicyAcceptEventView, "privacy_policy_accept_event.json"),
      roles: user.roles,
      preferences: render_one(user.preferences, PreferencesView, "preferences.json")}
      |> Enum.reject(fn {k, v} -> k == :password && is_nil(v) end)
      |> Enum.into(%{})
  end
end
