defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Controller do
  use <%= inspect context.web_module %>, :controller

  require Logger

  import <%= inspect context.web_module %>.PaginationController, only: [require_pagination: 2, pagination_info: 1]
  import <%= inspect context.base_module %>.Utils.Phoenix.Controller, only: [remote_ip_s: 1]

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  action_fallback <%= inspect context.web_module %>.FallbackController

  plug :require_pagination, [default_page_size: 10, max_page_size: 100] when action in [:index]

  def index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    <%= schema.plural %> = <%= inspect context.alias %>.list_<%= schema.plural %>(page_num, page_size)
    render(conn, "index.json", code: 200, <%= schema.plural %>: <%= schema.plural %>, page_num: page_num, page_size: page_size)
  end

  def create(conn, %{<%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    with {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} <- <%= inspect context.alias %>.create_<%= schema.singular %>(<%= schema.singular %>_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.<%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>))
      |> render("show.json", <%= schema.singular %>: <%= schema.singular %>)
    end
  end

  def show(conn, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    render(conn, "show.json", <%= schema.singular %>: <%= schema.singular %>)
  end

  def update(conn, %{"id" => id, <%= inspect schema.singular %> => <%= schema.singular %>_params}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)

    with {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} <- <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params) do
      render(conn, "show.json", <%= schema.singular %>: <%= schema.singular %>)
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)

    with {:ok, %<%= inspect schema.alias %>{}} <- <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>) do
      send_resp(conn, :no_content, "")
    end
  end
end
