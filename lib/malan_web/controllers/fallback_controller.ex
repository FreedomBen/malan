defmodule MalanWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.

  For a list of known status codes, see `Plug.Conn.Status` or
  https://hexdocs.pm/plug/Plug.Conn.Status.html#code/1-known-status-codes
  """
  use MalanWeb, :controller

  import MalanWeb.ChangesetView, only: [translate_errors: 1]

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MalanWeb.ErrorView)
    |> render("422.json", errors: translate_errors(changeset))
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(MalanWeb.ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, :too_many_requests}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(MalanWeb.ErrorView)
    |> render("429.json")
  end
end
