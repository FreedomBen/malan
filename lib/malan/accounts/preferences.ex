defmodule Malan.Accounts.Preference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :theme, :string
    field :default_sans, :string # temporary for testing. Replace when ready
  end

  def changeset(preferences, params) do
    preferences
    |> cast(params, [:theme, :default_sans])
    |> put_default_theme()
    |> validate_theme()
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
end
