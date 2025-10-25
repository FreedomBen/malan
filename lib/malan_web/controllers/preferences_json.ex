defmodule MalanWeb.PreferencesJSON do
  use MalanWeb, :view

  def render("preferences.json", %{preferences: preferences}) do
    %{
      theme: preferences.theme,
      display_name_pref: preferences.display_name_pref,
      display_middle_initial_only: preferences.display_middle_initial_only
    }
  end
end
