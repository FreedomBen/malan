defmodule MalanWeb.DocsController do
  use MalanWeb, {:controller, formats: [:html], layouts: []}

  @doc """
  Serve the OpenAPI specification file.
  """
  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/yaml")
    |> send_resp(200, File.read!(spec_path()))
  end

  @doc """
  Render Swagger UI backed by the local OpenAPI spec, serving assets locally.
  """
  def swagger(conn, _params) do
    html = """
    <!doctype html>
    <html lang=\"en\">
    <head>
      <meta charset=\"utf-8\" />
      <title>Malan API Docs</title>
      <link rel=\"stylesheet\" href=\"/swagger-ui/swagger-ui.css\" />
      <link rel=\"icon\" type=\"image/png\" href=\"/swagger-ui/favicon-32x32.png\" sizes=\"32x32\" />
      <link rel=\"icon\" type=\"image/png\" href=\"/swagger-ui/favicon-16x16.png\" sizes=\"16x16\" />
      <style>body { margin: 0; padding: 0; } #swagger-ui { min-height: 100vh; }</style>
    </head>
    <body>
      <div id=\"swagger-ui\"></div>
      <script src=\"/swagger-ui/swagger-ui-bundle.js\"></script>
      <script src=\"/swagger-ui/swagger-ui-standalone-preset.js\"></script>
      <script>
        window.onload = () => {
          SwaggerUIBundle({
            url: '/openapi.yaml',
            dom_id: '#swagger-ui',
            presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
            layout: 'BaseLayout'
          });
        };
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp spec_path, do: Path.expand("../../../openapi.yaml", __DIR__)
end
