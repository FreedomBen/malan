defmodule Malan.Accounts.Preference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :theme, :string
    field :display_name_pref, :string
  end

  def default_settings do
    %{theme: "light", display_name_pref: "nick_name"}
  end

  def changeset(preferences, params) do
    preferences
    |> cast(params, [:theme, :display_name_pref])
    |> put_default_theme()
    |> put_default_display_name_pref()
    |> validate_theme()
    |> validate_display_name_pref()
  end

  defp validate_theme(changeset) do
    case get_field(changeset, :theme) do
      "light" -> changeset
      "dark"  -> changeset
      _       -> add_error(changeset, :theme, "Valid themes are: 'dark', 'light'")
    end
  end

  defp put_default_theme(changeset) do
    cond do
      get_field(changeset, :theme) == nil ->
        put_change(changeset, :theme, "light")

      true ->
        changeset
    end
  end

  defp validate_display_name_pref(changeset) do
    case get_field(changeset, :display_name_pref) do
      "full_name" -> changeset
      "nick_name" -> changeset
      "custom"    -> changeset
      _ ->
        add_error(
          changeset,
          :display_name_pref,
          "Valid display_name_prefs are: 'full_name', 'nick_name', 'custom'"
        )
    end
  end

  defp put_default_display_name_pref(changeset) do
    cond do
      get_field(changeset, :display_name_pref) == nil ->
        put_change(changeset, :display_name_pref, "nick_name")

      true ->
        changeset
    end
  end
end
