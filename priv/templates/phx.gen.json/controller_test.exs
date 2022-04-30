defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  #import <%= inspect context.module %>Fixtures

  alias <%= inspect schema.module %>

  alias Malan.Test.Helpers

  @default_page_num 0
  @default_page_size 10

  @create_attrs %{
<%= schema.params.create |> Enum.map(fn {key, val} -> "    \"#{key}\" => #{inspect(val)}" end) |> Enum.join(",\n") %>
  }
  @update_attrs %{
<%= schema.params.update |> Enum.map(fn {key, val} -> "    \"#{key}\" => #{inspect(val)}" end) |> Enum.join(",\n") %>
  }
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>) do
    {:ok, <%= schema.singular %>} = <%= inspect context.module %>.create_<%= schema.singular %>(@create_attrs)
    <%= schema.singular %>
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index <%= schema.plural %>" do
    test "lists all <%= schema.plural %>", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :index))
      assert %{
        "ok" => true,
        "code" => 200,
        "page_num" => @default_page_num,
        "page_size" => @default_page_size,
        "data" => [],
      } = json_response(conn, 200)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :index))
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => _
      } = json_response(conn, 403)
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :index))
      # We haven't accepted the terms of service yet so expect 461
      assert %{
        "ok" => false,
        "code" => 461,
        "detail" => "Terms of Service Required",
        "message" => _
      } = json_response(conn, 461)

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :index))
      # We haven't accepted the PP yet so expect 462
      assert %{
        "ok" => false,
        "code" => 462,
        "detail" => "Privacy Policy Required",
        "message" =>_
      } = json_response(conn, 462)
    end
  end

  describe "show <%= schema.singular %>" do
    test "gets <%= schema.singular %>", %{conn: conn} do
      <%= schema.singular %> = fixture(:<%= schema.singular %>)
      id = <%= schema.singular %>.id
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, id))
      assert %{
        "ok" => true,
        "code" => 200,
        "detail" => "Forbidden",
        "data" => %{
           "id" => ^id<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>,
           "<%= key %>" => <%= inspect(val) %><% end %>
        }
      } = json_response(conn, 200)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, "42"))
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => _
      } = json_response(conn, 403)
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, user.id))
      # We haven't accepted the terms of service yet so expect 461
      assert %{
        "ok" => false,
        "code" => 461,
        "detail" => "Terms of Service Required",
        "message" => _
      } = json_response(conn, 461)

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, user.id))
      # We haven't accepted the PP yet so expect 462
      assert %{
        "ok" => false,
        "code" => 462,
        "detail" => "Privacy Policy Required",
        "message" =>_
      } = json_response(conn, 462)
    end
  end

  describe "create <%= schema.singular %>" do
    test "renders <%= schema.singular %> when data is valid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, id))

      assert %{
        "ok" => true,
        "code" => 200,
        "data" => %{
           "id" => ^id<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>,
           "<%= key %>" => <%= inspect(val) %><% end %>
        } = _<%= schema.singular %>,
      } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @invalid_attrs)
      assert %{
        "ok" => false,
        "code" => 422,
        "detail" => "Unprocessable Entity",
        "message" => _,
        "errors" => %{<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>
          "<%= key %>" => ["can't be blank"],<% end %>
        }
      } = json_response(conn, 422)
    end

    # If regular users should be allowed to create a <%= schema.singular %>, then remove this test
    test "won't work for regular user", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => _
      } = json_response(conn, 401)
    end

    test "requires being authenticated", %{conn: conn} do
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => _
      } = json_response(conn, 403)
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert %{
        "ok" => false,
        "code" => 461,
        "detail" => "Terms of Service Required",
        "message" => _
      } = json_response(conn, 461)

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      # We haven't accepted the PP yet so expect 462
      assert %{
        "ok" => false,
        "code" => 462,
        "detail" => "Privacy Policy Required",
        "message" =>_
      } = json_response(conn, 462)
    end
  end

  describe "update <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "renders <%= schema.singular %> when data is valid", %{conn: conn, <%= schema.singular %>: %<%= inspect schema.alias %>{id: id} = <%= schema.singular %>} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs)
      assert %{
        "ok" => true,
        "code" => 200,
        "data" => %{
           "id" => ^id<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>,
           "<%= key %>" => <%= inspect(val) %><% end %>
        } = _<%= schema.singular %>,
      } = json_response(conn, 200)

      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, id))

      assert %{
        "ok" => true,
        "code" => 200,
        "data" => %{
           "id" => ^id<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>,
           "<%= key %>" => <%= inspect(val) %><% end %>
        } = _<%= schema.singular %>,
      } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @invalid_attrs)
      assert %{
        "ok" => false,
        "code" => 422,
        "detail" => "Unprocessable Entity",
        "message" => _,
        "errors" => %{<%= for {key, val} <- schema.params.create |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() do %>
          "<%= key %>" => ["can't be blank"],<% end %>
        }
      } = json_response(conn, 422)
    end

    # If regular users should be allowed to update a <%= schema.singular %>, then remove this test
    test "won't work for regular user", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs)
      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => _
      } = json_response(conn, 401)
    end

    test "requires being authenticated", %{conn: conn, <%= schema.singular %>: _<%= schema.singular %>} do
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, "42"), <%= schema.singular %>: @update_attrs)
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => _
      } = json_response(conn, 403)
    end

    test "requires accepting ToS and PP", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert %{
        "ok" => false,
        "code" => 461,
        "detail" => "Terms of Service Required",
        "message" => _
      } = json_response(conn, 461)

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs)
      # We haven't accepted the PP yet so expect 462
      assert %{
        "ok" => false,
        "code" => 462,
        "detail" => "Privacy Policy Required",
        "message" =>_
      } = json_response(conn, 462)
    end
  end

  describe "delete <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "deletes chosen <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>))
      end
    end

    test "Requires being authenticated", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => _
      } = json_response(conn, 403)
    end

    # If regular users should be allowed to delete a <%= schema.singular %>, then remove this test
    test "won't work for regular user", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => _
      } = json_response(conn, 401)
    end

    test "requires accepting ToS and PP", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      # We haven't accepted the terms of service yet so expect 461
      assert %{
        "ok" => false,
        "code" => 461,
        "detail" => "Terms of Service Required",
        "message" => _
      } = json_response(conn, 461)

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      # We haven't accepted the PP yet so expect 462
      assert %{
        "ok" => false,
        "code" => 462,
        "detail" => "Privacy Policy Required",
        "message" =>_
      } = json_response(conn, 462)
    end
  end

  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    %{<%= schema.singular %>: <%= schema.singular %>}
  end
end
