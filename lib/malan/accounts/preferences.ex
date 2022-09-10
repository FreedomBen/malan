defmodule Malan.Accounts.Preference do
  use Ecto.Schema

  import Malan.Utils, only: [defp_testable: 2]
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :theme, :string, default: "light"
    field :display_name_pref, :string, default: "nick_name"
    field :display_middle_initial_only, :boolean, default: true
  end

  def default_settings do
    %{theme: "light", display_name_pref: "nick_name", display_middle_initial_only: true}
  end

  def changeset(preferences, params) do
    preferences
    |> cast(params, [:theme, :display_name_pref, :display_middle_initial_only])
    |> validate_theme()
    |> validate_display_name_pref()
    |> validate_display_middle_initial_only()
  end

  defp_testable validate_theme(changeset) do
    case get_field(changeset, :theme) do
      "light" -> changeset
      "dark" -> changeset
      _ -> add_error(changeset, :theme, "Valid themes are: 'dark', 'light'")
    end
  end

  defp_testable validate_display_name_pref(changeset) do
    case get_field(changeset, :display_name_pref) do
      "full_name" ->
        changeset

      "nick_name" ->
        changeset

      "custom" ->
        changeset

      _ ->
        add_error(
          changeset,
          :display_name_pref,
          "Valid display_name_prefs are: 'full_name', 'nick_name', 'custom'"
        )
    end
  end

  defp_testable validate_display_middle_initial_only(changeset) do
    case get_field(changeset, :display_middle_initial_only) do
      false ->
        changeset

      true ->
        changeset

      _ ->
        add_error(
          changeset,
          :display_middle_initial_only,
          "Valid display_middle_initial_only are: true, false"
        )
    end
  end
end
