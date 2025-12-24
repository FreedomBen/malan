defmodule MalanWeb.Plugs.EnsureOwnerOrAdmin do
  @moduledoc """
  Loads a record and ensures the authenticated user owns it (or is admin).

  Options:
    * `:loader` (required) - function of arity 1 that takes the record id and returns the record or nil
    * `:id_param` (required) - request param name containing the record id (e.g. "id")
    * `:owner_field` (optional) - field on the record that holds the owner id; defaults to :user_id
    * `:assign_as` (optional) - key to store the loaded record in assigns; defaults to :loaded_resource
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 2]
  import Malan.AuthController, only: [is_admin?: 1]

  alias MalanWeb.ErrorJSON

  def init(opts), do: opts

  def call(conn, opts) do
    id_param = Keyword.fetch!(opts, :id_param)
    loader = Keyword.fetch!(opts, :loader)
    owner_field = Keyword.get(opts, :owner_field, :user_id)
    assign_as = Keyword.get(opts, :assign_as, :loaded_resource)

    case Map.get(conn.params, id_param) do
      nil ->
        conn

      record_id ->
        case load_record(loader, record_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> put_view(ErrorJSON)
            |> render(:"404")
            |> halt()

          record ->
            cond do
              is_admin?(conn) ->
                assign(conn, assign_as, record)

              Map.get(record, owner_field) == conn.assigns.authed_user_id ->
                assign(conn, assign_as, record)

              true ->
                conn
                |> put_status(:unauthorized)
                |> put_view(ErrorJSON)
                |> render(:"401")
                |> halt()
            end
        end
    end
  end

  defp load_record(loader, id) when is_function(loader, 1) do
    try do
      loader.(id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end
end
