defmodule MalanWeb.PreferencesJSON do
  alias Malan.Accounts.Preference

  def preferences(%{preferences: preferences}), do: preference_data(preferences)
  def preferences(preferences), do: preference_data(preferences)

  defp preference_data(%Preference{} = preferences) do
    %{
      theme: preferences.theme,
      display_name_pref: preferences.display_name_pref,
      display_middle_initial_only: preferences.display_middle_initial_only
    }
  end

  defp preference_data(nil), do: nil
end
