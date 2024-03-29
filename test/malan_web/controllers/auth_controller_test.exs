defmodule MalanWeb.AuthControllerTest do
  use MalanWeb.ConnCase, async: true

  # alias Malan.Accounts
  # alias Malan.Accounts.{User, Session}

  alias Malan.Test.Helpers
  alias Malan.AuthController

  def validate_token(conn, api_token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_token}")
    |> AuthController.validate_token(nil)
  end

  def conn_assigns_for_invalid_token(auth_error) do
    %{
      authed_user_id: nil,
      authed_username: nil,
      authed_session_id: nil,
      authed_user_is_admin: false,
      authed_user_accepted_pp: false,
      authed_user_accepted_tos: false,
      authed_user_is_moderator: false,
      authed_session_ip_address: nil,
      authed_session_valid_only_for_ip: nil,
      authed_user_roles: [],
      auth_expires_at: nil,
      auth_error: auth_error
    }
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # validate_token/2 should assign the user_id to the conn in
  # :authed_user_id if the token is valid.  if not valid it should 
  # do nothing.  It should also assign :authed_user_roles with
  # the user's roles
  describe "#validate_token/2" do
    test "Adds proper assign when api_token is missing", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.fetch_session()
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:no_token)
    end

    test "Adds proper assigns when api_token is invalid", %{conn: conn} do
      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer invalidapitoken")
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:not_found)
    end

    test "Adds :authed_user_id to assigns and admin role", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{session.api_token}")
        |> AuthController.validate_token(nil)

      assert conn.assigns.authed_user_id == user.id
      assert conn.assigns.authed_username == user.username
      assert conn.assigns.authed_user_roles == ["admin", "user"]
      assert conn.assigns.authed_user_is_admin == true
      assert conn.assigns.authed_user_is_moderator == false
    end

    test "Adds :authed_user_id to assigns and moderator role", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.moderator_user_with_session()

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{session.api_token}")
        |> AuthController.validate_token(nil)

      assert conn.assigns.authed_user_id == user.id
      assert conn.assigns.authed_username == user.username
      assert conn.assigns.authed_user_roles == ["moderator", "user"]
      assert conn.assigns.authed_user_is_admin == false
      assert conn.assigns.authed_user_is_moderator == true
    end

    test "Adds :authed_user_id to assigns and user role", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{session.api_token}")
        |> AuthController.validate_token(nil)

      assert conn.assigns.authed_user_id == user.id
      assert conn.assigns.authed_username == user.username
      assert conn.assigns.authed_user_roles == ["user"]
      assert conn.assigns.authed_user_is_admin == false
      assert conn.assigns.authed_user_accepted_pp == false
      assert conn.assigns.authed_user_accepted_tos == false
      assert conn.assigns.authed_user_is_moderator == false
    end

    test "Handles malformed token", %{conn: conn} do
      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer invalidapitoken")
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:not_found)
    end

    test "Handles empty token", %{conn: conn} do
      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer")
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:malformed)

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "")
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:malformed)
    end

    test "Adds IP address and valid_only_for_ip", %{conn: conn} do
      {:ok, user, session} =
        Helpers.Accounts.regular_user_with_session(%{}, %{
          "ip_address" => "127.0.0.1",
          "valid_only_for_ip" => true
        })

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{session.api_token}")
        |> AuthController.validate_token(nil)

      assert conn.assigns.auth_error == nil
      assert conn.assigns.authed_user_id == user.id
      assert conn.assigns.authed_username == user.username
      assert conn.assigns.authed_user_roles == ["user"]
      assert conn.assigns.authed_user_is_admin == false
      assert conn.assigns.authed_user_accepted_pp == false
      assert conn.assigns.authed_user_accepted_tos == false
      assert conn.assigns.authed_user_is_moderator == false
      assert conn.assigns.authed_session_ip_address == "127.0.0.1"
      assert conn.assigns.authed_session_valid_only_for_ip == true
    end

    test "Invalid and adds IP address and valid_only_for_ip when IP is wrong", %{conn: conn} do
      {:ok, _user, session} =
        Helpers.Accounts.regular_user_with_session(%{}, %{
          "ip_address" => "1.1.1.1",
          "valid_only_for_ip" => true
        })

      conn =
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{session.api_token}")
        |> AuthController.validate_token(nil)

      assert conn.assigns.auth_error == :ip_addr
      assert conn.assigns.authed_user_id == nil
      assert conn.assigns.authed_username == nil
      assert conn.assigns.authed_user_roles == []
      assert conn.assigns.authed_user_is_admin == false
      assert conn.assigns.authed_user_accepted_pp == false
      assert conn.assigns.authed_user_accepted_tos == false
      assert conn.assigns.authed_user_is_moderator == false
      assert conn.assigns.authed_session_ip_address == nil
      assert conn.assigns.authed_session_valid_only_for_ip == nil
    end

    test "Handles no token in header or in session cookie", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.fetch_session()
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:no_token)
    end

    test "Handles invalid token in cookie", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{"authorization" => "hey"})
        |> Plug.Conn.fetch_session()
        |> AuthController.validate_token(nil)

      assert conn.assigns == conn_assigns_for_invalid_token(:not_found)
    end

    test "Can get the token from the session cookie (admin user)", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{"authorization" => session.api_token})
        |> Plug.Conn.fetch_session()
        |> AuthController.validate_token(nil)

      assert conn.assigns.authed_user_id == user.id
      assert conn.assigns.authed_username == user.username
      assert conn.assigns.authed_user_roles == ["admin", "user"]
      assert conn.assigns.authed_user_is_admin == true
      assert conn.assigns.authed_user_is_moderator == false
    end

  end

  describe "#is_authenticated/2" do
    test "does not halt when authenticated", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_authenticated(nil)

      assert conn.halted == false
      assert conn.status == nil
    end

    test "halts when not authenticated", %{conn: conn} do
      conn =
        validate_token(conn, "helloworld")
        |> AuthController.is_authenticated(nil)

      assert conn.halted == true
      assert conn.status == 403

      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token.",
      } = json_response(conn, 403)
    end

    test "halts with 403 when token expired", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()

      c1 =
        validate_token(conn, session.api_token)
        |> AuthController.is_authenticated(nil)

      assert c1.halted == false
      assert c1.status == nil

      session = Helpers.Accounts.set_expired(session)

      c2 =
        validate_token(conn, session.api_token)
        |> AuthController.is_authenticated(nil)

      assert c2.halted == true
      assert c2.status == 403

      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => "API token is expired or revoked",
        "token_expired" => true
      } = json_response(c2, 403)
    end

    test "halts with 403 when token revoked", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()

      c1 =
        validate_token(conn, session.api_token)
        |> AuthController.is_authenticated(nil)

      assert c1.halted == false
      assert c1.status == nil

      session = Helpers.Accounts.set_expired(session)

      c2 =
        validate_token(conn, session.api_token)
        |> AuthController.is_authenticated(nil)

      assert c2.halted == true
      assert c2.status == 403
      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => "API token is expired or revoked",
        "token_expired" => true
      } = json_response(c2, 403)
    end
  end

  describe "#is_admin/2" do
    test "does not halt when logged in as admin", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.admin_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_admin(nil)

      assert conn.halted == false
      assert conn.status == nil
    end

    test "halts when authenticated as regular user (not an admin)", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_admin(nil)

      assert conn.halted == true
      assert conn.status == 401
    end

    test "halts when authenticated but moderator (not an admin)", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.moderator_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_admin(nil)

      assert conn.halted == true
      assert conn.status == 401
    end

    test "halts when not authenticated", %{conn: conn} do
      conn =
        validate_token(conn, "helloworld")
        |> AuthController.is_admin(nil)

      assert conn.halted == true
      assert conn.status == 403
    end
  end

  describe "#is_moderator/2" do
    test "does not halt when logged in as admin", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.admin_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_moderator(nil)

      assert conn.halted == false
      assert conn.status == nil
    end

    test "does not halt when logged in as moderator", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.moderator_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_moderator(nil)

      assert conn.halted == false
      assert conn.status == nil
    end

    test "halts when authenticated as regular user (not a moderator)", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()

      conn =
        validate_token(conn, session.api_token)
        |> AuthController.is_moderator(nil)

      assert conn.halted == true
      assert conn.status == 401
    end

    test "halts when not authenticated", %{conn: conn} do
      conn =
        validate_token(conn, "helloworld")
        |> AuthController.is_moderator(nil)

      assert conn.halted == true
      assert conn.status == 403
    end
  end

  describe "#is_owner_or_admin/2" do
    # TODO
  end

  describe "#is_admin?/1" do
    test "works" do
      assert true == AuthController.is_admin?(%{assigns: %{authed_user_is_admin: true}})
      assert false == AuthController.is_admin?(%{assigns: %{authed_user_is_admin: false}})
      assert false == AuthController.is_admin?(%{assigns: %{authed_user_is_admin: nil}})
    end
  end

  describe "#is_not_admin?/1" do
    test "works" do
      assert false == AuthController.is_not_admin?(%{assigns: %{authed_user_is_admin: true}})
      assert true == AuthController.is_not_admin?(%{assigns: %{authed_user_is_admin: false}})
      assert true == AuthController.is_not_admin?(%{assigns: %{authed_user_is_admin: nil}})
    end
  end

  describe "#is_moderator?/1" do
    test "works" do
      assert true == AuthController.is_moderator?(%{assigns: %{authed_user_is_moderator: true}})
      assert false == AuthController.is_moderator?(%{assigns: %{authed_user_is_moderator: false}})
      assert false == AuthController.is_moderator?(%{assigns: %{authed_user_is_moderator: nil}})
    end
  end

  describe "#is_not_moderator?/1" do
    test "works" do
      assert false ==
               AuthController.is_not_moderator?(%{assigns: %{authed_user_is_moderator: true}})

      assert true ==
               AuthController.is_not_moderator?(%{assigns: %{authed_user_is_moderator: false}})

      assert true ==
               AuthController.is_not_moderator?(%{assigns: %{authed_user_is_moderator: nil}})
    end
  end

  describe "#is_moderator_or_admin?/1" do
    test "works" do
      assert true ==
               AuthController.is_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: true, authed_user_is_admin: false}
               })

      assert true ==
               AuthController.is_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: true}
               })

      assert false ==
               AuthController.is_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: false}
               })
    end
  end

  describe "#is_not_moderator_or_admin?/1" do
    test "works" do
      assert false ==
               AuthController.is_not_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: true, authed_user_is_admin: false}
               })

      assert false ==
               AuthController.is_not_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: true}
               })

      assert true ==
               AuthController.is_not_moderator_or_admin?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: false}
               })
    end
  end

  describe "#is_admin_or_moderator?/1" do
    test "works" do
      assert true ==
               AuthController.is_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: true, authed_user_is_admin: false}
               })

      assert true ==
               AuthController.is_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: true}
               })

      assert false ==
               AuthController.is_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: false}
               })
    end
  end

  describe "#is_not_admin_or_moderator?/1" do
    test "works" do
      assert false ==
               AuthController.is_not_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: true, authed_user_is_admin: false}
               })

      assert false ==
               AuthController.is_not_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: true}
               })

      assert true ==
               AuthController.is_not_admin_or_moderator?(%{
                 assigns: %{authed_user_is_moderator: false, authed_user_is_admin: false}
               })
    end
  end

  describe "#is_owner?/1" do
    test "works for user id" do
      assert true ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => "abc"}
               })

      assert false ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => "123"}
               })

      assert false ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => nil}
               })
    end

    test "works for username" do
      assert true ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => "def"}
               })

      assert false ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => "123"}
               })

      assert false ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => nil}
               })
    end

    test "works for user id 'current'" do
      assert true ==
               AuthController.is_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => "current"}
               })
    end
  end

  describe "#is_owner?/2" do
    test "works for user id" do
      assert true ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 "abc"
               )

      assert false ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 "123"
               )

      assert false ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 nil
               )
    end

    test "works for username" do
      assert true ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 "def"
               )

      assert false ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 "123"
               )

      assert false ==
               AuthController.is_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 nil
               )
    end
  end

  describe "#is_not_owner?/1" do
    test "works for user id" do
      assert false ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => "abc"}
               })

      assert true ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => "123"}
               })

      assert true ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "abc", authed_username: ""},
                 params: %{"user_id" => nil}
               })
    end

    test "works for username" do
      assert false ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => "def"}
               })

      assert true ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => "123"}
               })

      assert true ==
               AuthController.is_not_owner?(%{
                 assigns: %{authed_user_id: "", authed_username: "def"},
                 params: %{"user_id" => nil}
               })
    end
  end

  describe "#is_not_owner?/2" do
    test "works for user id" do
      assert false ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 "abc"
               )

      assert true ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 "123"
               )

      assert true ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "abc", authed_username: ""}},
                 nil
               )
    end

    test "works for username" do
      assert false ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 "def"
               )

      assert true ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 "123"
               )

      assert true ==
               AuthController.is_not_owner?(
                 %{assigns: %{authed_user_id: "", authed_username: "def"}},
                 nil
               )
    end
  end

  describe "#authed_user_and_session/1" do
    test "works correctly" do
      assert {"abcdefg", "hijklmnop"} ==
               AuthController.authed_user_and_session(%Plug.Conn{
                 assigns: %{authed_user_id: "abcdefg", authed_session_id: "hijklmnop"}
               })

      assert {"abcdefg", nil} ==
               AuthController.authed_user_and_session(%Plug.Conn{
                 assigns: %{authed_user_id: "abcdefg"}
               })

      assert {nil, "hijklmnop"} ==
               AuthController.authed_user_and_session(%Plug.Conn{
                 assigns: %{authed_session_id: "hijklmnop"}
               })

      assert {nil, nil} == AuthController.authed_user_and_session(%Plug.Conn{assigns: %{}})
      assert {nil, nil} == AuthController.authed_user_and_session(%Plug.Conn{})
    end
  end
end
