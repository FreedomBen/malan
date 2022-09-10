defmodule Malan.Accounts.Transaction.Changes do
  @moduledoc """
  Malan.Accounts.Transaction.Changes is used store a record of changes related to a `Malan.Accounts.Transaction`

  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.Utils

  @valid_data_types [
    nil,
    "",
    "users",
    "sessions"
  ]

  # Attrs that are always filtered
  @blacklisted_attrs [
    :password,
    :password_reset_token,
    :api_token
  ]

  defguard valid_data_type(data_type) when data_type in @valid_data_types

  @derive Jason.Encoder

  embedded_schema do
    field :errors, {:array, :string}, default: []
    field :changes, :map, default: %{}
    field :data, :map, default: %{}
    field :data_type, :string
    field :action, :string, default: ""
    field :valid?, :boolean
    field :outcome, :map, default: %{} # The object that results from the operation
  end

  def blattrs(blacklisted_attrs \\ []) do
    @blacklisted_attrs ++ blacklisted_attrs
  end

  def map_from_changeset(changeset, blacklisted_attrs \\ []) do
    bl_attrs = blattrs(blacklisted_attrs)
    %{
      errors: changeset.errors |> Utils.Ecto.Changeset.errors_to_str_list(),
      #changes: changeset.changes |> Utils.mask_map_key_values(bl_attrs),
      changes: changeset.changes |> clean_changeset_changes(bl_attrs),
      data: changeset.data |> clean_changeset_data(bl_attrs),
      data_type: changeset.data.__meta__.source,
      action: changeset.action,
      valid?: changeset.valid?
    }
  end

  # def from_changeset(changeset, blacklisted_attrs \\ []) do
  #   changeset(%__MODULE__{}, map_from_changeset(changeset, blacklisted_attrs))
  # end

  def changeset(tx_changes, attrs) do
    tx_changes
    |> cast(attrs, [:errors, :changes, :data, :data_type, :action, :valid?])
    #|> validate_required([:errors, :changes, :data, :data_type, :valid?])
    |> validate_data_type()
  end

  def validate_data_type(changeset) do
    case get_field(changeset, :data_type) in @valid_data_types do
      true ->
        changeset

      false ->
        Ecto.Changeset.add_error(
          changeset,
          :data_type,
          "data_type is invalid.  Should be one of: '#{Enum.join(@valid_data_types, ", ")}'"
        )
    end
  end

  defp clean_changeset_data(data, bl_attrs) do
    data
    |> Utils.struct_to_map(bl_attrs)
    |> Utils.remove_not_loaded()
  end

  defp clean_changeset_changes(changes, bl_attrs) do
    changes
    |> Utils.mask_map_key_values(bl_attrs)
    |> Utils.Ecto.Changeset.convert_changes()
  end
end
