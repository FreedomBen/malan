defmodule MalanWeb.PreferencesView do
  use MalanWeb, :view

  def render("preferences.json", %{preferences: preferences}) do
    %{theme: preferences.theme}
  end
end
