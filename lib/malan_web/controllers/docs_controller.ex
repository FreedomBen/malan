defmodule MalanWeb.DocsController do
  use MalanWeb, {:controller, formats: [:html, :json, :yaml], layouts: []}

  @doc """
  Serve the OpenAPI specification file.
  """
  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/vnd.oai.openapi+yaml")
    |> send_file(200, spec_path())
  end

  @doc """
  Render Swagger UI backed by the local OpenAPI spec, serving assets locally.
  """
  def swagger(conn, _params) do
    render(conn, :swagger, layout: false)
  end

  defp spec_path, do: Application.app_dir(:malan, "priv/openapi/openapi.yaml")
end
