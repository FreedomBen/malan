defmodule MalanWeb.Plugs.AppleAppSiteAssociationMime do
  @moduledoc """
  A plug that serves the Apple App Site Association file with the correct MIME type.
  This is needed because the file has no extension, making it hard for Phoenix
  to determine the correct MIME type.
  """
  @behaviour Plug
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.request_path == "/.well-known/apple-app-site-association" do
      # Path to the file
      file_path =
        Path.join([:code.priv_dir(:malan), "static", ".well-known", "apple-app-site-association"])

      # Read the file
      case File.read(file_path) do
        {:ok, content} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, content)
          |> halt()

        {:error, _} ->
          conn
      end
    else
      conn
    end
  end
end
