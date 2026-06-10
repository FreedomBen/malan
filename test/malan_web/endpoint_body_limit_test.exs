defmodule MalanWeb.EndpointBodyLimitTest do
  use MalanWeb.ConnCase, async: true

  alias Malan.Test.Helpers

  test "rejects request bodies over the 1 MB cap with 413", %{conn: conn} do
    # Raw binary body so the request actually streams through
    # Plug.Parsers' read_body (map params can short-circuit parsing in
    # test). Parsers raises Plug.Parsers.RequestTooLargeError (413) when
    # the body exceeds the configured length.
    big_body = Jason.encode!(%{user: %{junk: String.duplicate("a", 1_100_000)}})

    assert_error_sent 413, fn ->
      conn
      |> put_req_header("content-type", "application/json")
      |> post(Routes.user_path(conn, :create), big_body)
    end
  end

  test "accepts large-but-under-limit bodies", %{conn: conn} do
    {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)

    # ~200 KB custom_attrs payload — far larger than a typical request
    # but well under the cap. Raw body so it streams through the parser.
    body = Jason.encode!(%{user: %{custom_attrs: %{"blob" => String.duplicate("x", 200_000)}}})

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put(Routes.user_path(conn, :update, user.id), body)

    assert %{"data" => %{"custom_attrs" => %{"blob" => _}}} = json_response(conn, 200)
  end
end
