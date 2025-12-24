defmodule Mix.Tasks.Openapi.Copy do
  @moduledoc """
  Copy the source OpenAPI spec into the static docs directory so
  Plug.Static (and phx.digest) can serve/cache-bust it.
  """
  use Mix.Task

  @shortdoc "Copy priv/openapi/openapi.yaml to priv/static/docs/openapi.yaml"

  @impl Mix.Task
  def run(_args) do
    source = Path.join(["priv", "openapi", "openapi.yaml"])
    dest_dir = Path.join(["priv", "static", "docs"])
    dest = Path.join(dest_dir, "openapi.yaml")

    File.mkdir_p!(dest_dir)
    File.cp!(source, dest)

    Mix.shell().info("Copied #{source} -> #{dest}")
  end
end
