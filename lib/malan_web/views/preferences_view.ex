defmodule MalanWeb.PreferencesView do
  use MalanWeb, :view
  alias MalanWeb.PreferencesView

  def render("preferences.json", %{preferences: preferences}) do
    %{theme: preferences.theme}
  end
end
