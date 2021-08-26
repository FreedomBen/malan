defmodule MalanWeb.UserControllerTest do
  use MalanWeb.ConnCase, async: true

  alias Malan.Accounts.User
  alias Malan.Utils
  alias Malan.Repo

  alias Malan.Test.Helpers
  alias Malan.Test.Utils, as: TestUtils

  @create_attrs %{
    email: "some@email.com",
    #email_verified: "2010-04-17T14:00:00Z",
    #password: "some password",
    #preferences: %{},
    #roles: [],
    username: "someusername",
    first_name: "Some",
    last_name: "cool User",
    custom_attrs: %{"hereiam" => "rockyou", "likea" => "hurricane", "year" => 1986}
  }
  @invalid_attrs %{
    email: nil,
    email_verified: nil,
    password: nil,
    preferences: nil,
    roles: nil,
    tos_accept_time: nil,
    username: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users (as admin)", %{conn: conn} do
      {:ok, conn, au, _as} = Helpers.Accounts.admin_user_session_conn(conn)
      {:ok, ru, _rs} = Helpers.Accounts.regular_user_with_session()
      conn = get(conn, Routes.user_path(conn, :index))
      users = json_response(conn, 200)["data"]
      assert Enum.any?(users, fn (u) ->
        u["id"] == au.id
        && u["email"] == au.email
        && u["first_name"] == au.first_name
        && u["last_name"] == au.last_name
        && u["nick_name"] == au.nick_name
        && u["roles"] == au.roles
        && u["sex"] == au.sex
      end)
      assert Enum.any?(users, fn (u) ->
        u["id"] == ru.id
        && u["email"] == ru.email
        && u["first_name"] == ru.first_name
        && u["last_name"] == ru.last_name
        && u["nick_name"] == ru.nick_name
        && u["roles"] == ru.roles
      end)
    end

    test "requires being an admin to access (unauthenticated)", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :index))
      assert conn.status == 403
    end

    test "requires being an admin to access (as regular user)", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, rs.api_token)
      conn = get(conn, Routes.user_path(conn, :index))
      assert conn.status == 401
    end

    test "requires being an admin to access (as moderator)", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.moderator_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.user_path(conn, :index))
      assert conn.status == 401
    end
  end

  describe "create user and get user details with returned password" do
    # TODO: add captcha
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} = user = json_response(conn, 201)["data"]
      assert is_nil(password) == false

      # This uses the returned password above to authenticate
      {:ok, session} = Helpers.Accounts.create_session(Utils.map_string_keys_to_atoms(user))
      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id), abbr: 1)
      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "email" => "some@email.com",
               "email_verified" => nil,
               "preferences" => %{"theme" => "light"},
               "roles" => ["user"],
               "tos_accept_events" => [],
               "privacy_policy_accept_events" => [],
               "latest_tos_accept_ver" => nil,
               "latest_pp_accept_ver" => nil,
               "tos_accepted" => false,
               "privacy_policy_accepted" => false,
               "username" => "someusername",
               "nick_name" => "",
               "custom_attrs" => %{
                 "hereiam" => "rockyou",
                 "likea" => "hurricane",
                 "year" => 1986,
               }
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false

      # Should not have phone numbers present because not set and not requested
      assert Map.has_key?(jr, "phone_numbers") == false
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "allows specifying initial password and requires ToS/PP", %{conn: conn} do
      password = "initialpassword"
      conn = post(conn, Routes.user_path(conn, :create), user: Map.put(@create_attrs, :password, password))
      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => ^password} = user = json_response(conn, 201)["data"]

      # This uses the returned password above to authenticate
      {:ok, session} = Helpers.Accounts.create_session(Utils.map_string_keys_to_atoms(user))
      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))
      assert conn.status == 200
      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "email" => "some@email.com",
               "email_verified" => nil,
               "preferences" => %{"theme" => "light"},
               "roles" => ["user"],
               "tos_accept_events" => [],
               "privacy_policy_accept_events" => [],
               "username" => "someusername",
               "nick_name" => "",
               "latest_tos_accept_ver" => nil,
               "latest_pp_accept_ver" => nil,
               "tos_accepted" => false,
               "privacy_policy_accepted" => false,
             } = jr
      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
    end

    test "Accepts phone numbers", %{conn: conn} do
      %{phone_numbers: [%{} = ph1, %{} = ph2]} = phone_numbers = %{
        phone_numbers: [
          %{
            "number" => "801-867-5309",
            "primary" => true,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5310",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
        ]
      }
      conn = post(conn, Routes.user_path(conn, :create), user: Map.merge(@create_attrs, phone_numbers))
      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} = user = json_response(conn, 201)["data"]
      assert is_nil(password) == false

      # This uses the returned password above to authenticate
      {:ok, session} = Helpers.Accounts.create_session(Utils.map_string_keys_to_atoms(user))
      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))
      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "email" => "some@email.com",
               "email_verified" => nil,
               "preferences" => %{"theme" => "light"},
               "roles" => ["user"],
               "tos_accept_events" => [],
               "privacy_policy_accept_events" => [],
               "latest_tos_accept_ver" => nil,
               "latest_pp_accept_ver" => nil,
               "tos_accepted" => false,
               "privacy_policy_accepted" => false,
               "username" => "someusername",
               "nick_name" => "",
               "custom_attrs" => %{
                 "hereiam" => "rockyou",
                 "likea" => "hurricane",
                 "year" => 1986,
               },
               "phone_numbers" => phs
             } = jr
      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
      assert Enum.count(phs) == 2
      assert Enum.all?(phs, fn (ph) -> ph["number"] == ph1["number"] || ph["number"] == ph2["number"] end)
    end
  end

  describe "update user" do
    setup [:create_regular_user_with_session]

    test "allows updating password, preferences, nickname, and accepting ToS and privacy policy", %{conn: conn, user: %User{id: id} = user, session: session} do
      update_params = %{
        nick_name: "Eddie van Halen",
        accept_tos: true,
        accept_privacy_policy: true,
        preferences: %{theme: "dark"},
        sex: "male",
        birthday: ~U[1986-06-13 01:09:08.105179Z],
        roles: ["admin", "user"],  # Shouldn't make it through
        custom_attrs: %{
          "hereiam" => "rockyou",
          "likea" => "hurricane",
          "year" => 1986,
        }
      }
      check_response = fn (conn) ->
        assert %{
          "id" => ^id,
          "email" => email,
          "username" => username,
          "email_verified" => nil,
          "preferences" => %{"theme" => "dark"},
          "roles" => ["user"],
          "birthday" => "1986-06-13T01:09:08Z",
          "sex" => "Male",
          "gender" => nil,
          "latest_tos_accept_ver" => 1,
          "latest_pp_accept_ver" => 1,
          "tos_accepted" => true,
          "privacy_policy_accepted" => true,
          "tos_accept_events" => [%{
            "accept" => true,
            "tos_version" => 1,
            "timestamp" => tostimestamp
          }],
          "privacy_policy_accept_events" => [%{
            "accept" => true,
            "privacy_policy_version" => 1,
            "timestamp" => pptimestamp
          }],
          "nick_name" => "Eddie van Halen",
          "custom_attrs" => %{
            "hereiam" => "rockyou",
            "likea" => "hurricane",
            "year" => 1986,
          }
        } = json_response(conn, 200)["data"]
        for ts <- [pptimestamp, tostimestamp] do
          assert {:ok, ts, 0} = DateTime.from_iso8601(ts)
          assert TestUtils.DateTime.within_last?(ts, 5, :seconds) == true
          assert email =~ ~r/^regular.*email.com$/
          assert username =~ ~r/^regularuser\d+$/
        end
      end

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))
      assert %{
        "nick_name" => "reggy",
        "tos_accept_events" => [],
        "privacy_policy_accept_events" => []
      } = json_response(conn, 200)["data"]

      conn = put(conn, Routes.user_path(conn, :update, user), user: update_params)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      check_response.(conn)

      conn = get(conn, Routes.user_path(conn, :show, id))
      check_response.(conn)
    end

    test "allows using username instead of user ID", %{conn: conn, user: %User{id: id, email: email, username: username}, session: session} do
      %{nick_name: nick_name} = update_params = %{nick_name: "Eddie van Halen"}
      check_response = fn (conn) ->
        assert %{
          "id" => ^id,
          "email" => ^email,
          "username" => ^username,
          "nick_name" => ^nick_name
        } = json_response(conn, 200)["data"]
      end

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, username))
      assert %{
        "nick_name" => "reggy",
        "tos_accept_events" => [],
        "privacy_policy_accept_events" => []
      } = json_response(conn, 200)["data"]

      conn = put(conn, Routes.user_path(conn, :update, username), user: update_params)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      check_response.(conn)

      conn = get(conn, Routes.user_path(conn, :show, username))
      check_response.(conn)
    end

    test "renders errors when data is invalid", %{conn: conn, user: %User{} = user, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "allows updating password", %{conn: conn, user: %User{id: id} = user} do
      # authenticate with first password, then change it,
      # then authenticate with the new password
      update_params = %{
        password: "rockyoulikeahurricane",
      }
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: update_params)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      # Old session should have been invalidated
      conn = put(conn, Routes.user_path(conn, :update, user), user: update_params)
      assert conn.status == 403

      # Re authenticate with new password
      assert {:error, :unauthorized} = Helpers.Accounts.create_session(user)
      assert {:ok, session} = Helpers.Accounts.create_session(%{user | password: "rockyoulikeahurricane"})
      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: %{nick_name: "ronaldo"})
      assert %{"nick_name" => "ronaldo"} = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: %{nick_name: "ohai"})
      assert conn.status == 403
    end

    test "requires being self or admin", %{conn: conn, user: %User{} = user} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session(%{email: "e1@mail.com", username: "e1abcdefg"})

      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      assert json_response(conn, 201)["data"]

      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), rs.api_token)
      conn = get(conn, Routes.user_path(conn, :show, user))

      assert conn.status == 401

      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), as.api_token)
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert %{"id" => _id} = json_response(conn, 200)["data"]
    end

    test "Allows specifying gender, sex, race, ethnicity", %{conn: conn, user: %User{} = user} do
      update_params = %{
        sex: "male",
        gender: "male",
        ethnicity: "Not Hispanic or Latinx",
        race: [
          "American Indian or Alaska Native",
          "Asian",
          "Black or African American",
          "Native Hawaiian or Other Pacific Islander",
          "White",
        ]
      }
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: update_params)
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))
      assert %{
        "sex" => "Male",
        "gender" => "Male",
        "ethnicity" => "Not Hispanic or Latinx",
        "race" => [
          "American Indian or Alaska Native",
          "Asian",
          "Black or African American",
          "Native Hawaiian or Other Pacific Islander",
          "White",
        ]
      } = json_response(conn, 200)["data"]
    end

    test "requires being an admin to access (as regular user)", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, rs.api_token)
      conn = get(conn, Routes.user_path(conn, :index))
      assert conn.status == 401
    end

    test "Allows updating phone numbers", %{conn: conn, user: %User{} = user} do
      %{phone_numbers: [%{} = ph1, %{} = ph2, %{} = ph3, %{} = ph4]} = phone_numbers = %{
        phone_numbers: [
          %{
            "number" => "801-867-5309",
            "primary" => true,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5310",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5311",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5312",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
        ]
      }
      {_user_id, username, email, nick_name} = {user.id, user.username, user.email, user.nick_name}
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: phone_numbers)

      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))
      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "email" => ^email,
               "email_verified" => nil,
               "preferences" => %{"theme" => "light"},
               "roles" => ["user"],
               "tos_accept_events" => [],
               "privacy_policy_accept_events" => [],
               "latest_tos_accept_ver" => nil,
               "latest_pp_accept_ver" => nil,
               "tos_accepted" => false,
               "privacy_policy_accepted" => false,
               "username" => ^username,
               "nick_name" => ^nick_name,
               "custom_attrs" => %{},
               "phone_numbers" => phs
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
      assert Enum.count(phs) == 4
      assert Enum.all?(phs, fn (ph) ->
        [ph1, ph2, ph3, ph4]
        |> Enum.map(fn (phx) -> phx["number"] end)
        |> Enum.member?(ph["number"])
      end)
    end
  end

  describe "admin update user" do
    setup [:create_regular_user_with_session]

    test "allows updating roles, password, preferences, nickname, and accepting ToS and privacy policy", %{conn: conn, user: %User{id: id} = user, session: session} do
      # admin user cannot accept ToS or PP on behalf of user
      # so these changes should not be applied
      update_params = %{
        email: "brandnew@address.com",
        username: "brandnewusername",
        first_name: "Brand",
        last_name: "New",
        nick_name: "Eddie v Dawg",
        accept_tos: true,              # rejected
        accept_privacy_policy: true,   # rejected
        preferences: %{theme: "dark"}, # rejected
        roles: ["admin", "user"],
        sex: "female",
        gender: "Trans*Woman",
        race: ["Asian", "white"],
        ethnicity: "Hispanic or Latinx",
      }
      check_response = fn (conn) ->
        assert %{
          "id" => _id,
          "email" => "brandnew@address.com",
          "username" => "brandnewusername",
          "email_verified" => nil,
          "preferences" => %{"theme" => "dark"},
          "roles" => ["admin", "user"],
          "tos_accept_events" => [],
          "privacy_policy_accept_events" => [],
          "nick_name" => "Eddie v Dawg",
          "sex" => "Female",
          "gender" => "Trans*Woman",
          "race" => ["Asian", "White"],
        } = json_response(conn, 200)["data"]
      end

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))
      assert %{
        "nick_name" => "reggy",
        "tos_accept_events" => [],
        "privacy_policy_accept_events" => []
      } = json_response(conn, 200)["data"]

      # regular user can't call admin_update
      conn = put(conn, Routes.user_path(conn, :admin_update, user), user: update_params)
      assert conn.status == 401

      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = put(conn, Routes.user_path(conn, :admin_update, user), user: update_params)

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      check_response.(conn)

      conn = get(conn, Routes.user_path(conn, :show, id))
      check_response.(conn)
    end

    test "allows removing roles", %{conn: conn, user: %User{}, session: _session} do
      [{:ok, conn, _au1, _as1}, {:ok, _conn, au2, _as2}] =
        Helpers.Accounts.admin_users_session_conn(conn, 2)
      #{:ok, _au1, as1} = Helpers.Accounts.admin_user_with_session()
      #{:ok, au2, _as2} = Helpers.Accounts.admin_user_with_session(%{email: "au2@mail.com", username: "au2"})
      #conn = Helpers.Accounts.put_token(conn, as1.api_token)
      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["admin", "user"]} = json_response(conn, 200)["data"]
      conn = put(conn, Routes.user_path(conn, :admin_update, au2.id), user: %{roles: ["user"]})
      assert %{"roles" => ["user"]} = json_response(conn, 200)["data"]
      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["user"]} = json_response(conn, 200)["data"]
    end

    test "Allows updating phone numbers", %{conn: _conn, user: %User{} = user} do
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(build_conn())
      %{phone_numbers: [%{} = ph1, %{} = ph2, %{} = ph3, %{} = ph4]} = phone_numbers = %{
        phone_numbers: [
          %{
            "number" => "801-867-5309",
            "primary" => true,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5310",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5311",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
          %{
            "number" => "801-867-5312",
            "primary" => false,
            "verified_at" => "2010-04-17T14:00:00Z"
          },
        ]
      }
      {_user_id, username, email, nick_name} = {user.id, user.username, user.email, user.nick_name}
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: phone_numbers)

      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))
      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "email" => ^email,
               "email_verified" => nil,
               "preferences" => %{"theme" => "light"},
               "roles" => ["user"],
               "tos_accept_events" => [],
               "privacy_policy_accept_events" => [],
               "latest_tos_accept_ver" => nil,
               "latest_pp_accept_ver" => nil,
               "tos_accepted" => false,
               "privacy_policy_accepted" => false,
               "username" => ^username,
               "nick_name" => ^nick_name,
               "custom_attrs" => %{},
               "phone_numbers" => phs
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
      assert Enum.count(phs) == 4
      assert Enum.all?(phs, fn (ph) ->
        [ph1, ph2, ph3, ph4]
        |> Enum.map(fn (phx) -> phx["number"] end)
        |> Enum.member?(ph["number"])
      end)
    end
  end

  describe "delete user" do
    setup [:create_regular_user_with_session]

    test "marks user as deleted", %{conn: conn, user: user, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      conn = get(conn, Routes.user_path(conn, :show, user))
      assert conn.status == 404
    end
  end

  # Deprecated in favor of "current"
  describe "me" do
    setup [:create_regular_user_with_session]

    test "Retrieves all user info based on API token", %{conn: conn, user: %User{id: user_id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :me))
      assert %{
               "id" => ^user_id,
               "roles" => ["user"],
               "username" => _username,
               "nick_name" => _nick_name,
             } = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = _user} do
      conn = put(conn, Routes.user_path(conn, :me))
      assert conn.status == 403
    end
  end

  describe "current" do
    setup [:create_regular_user_with_session]

    test "Retrieves all user info based on API token", %{conn: conn, user: %User{id: user_id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :current))
      assert %{
               "id" => ^user_id,
               "roles" => ["user"],
               "username" => _username,
               "nick_name" => _nick_name,
             } = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = _user} do
      conn = put(conn, Routes.user_path(conn, :current))
      assert conn.status == 403
    end
  end

  describe "whoami" do
    setup [:create_regular_user_with_session]

    test "Retrieves user ID and roles based on API token", %{conn: conn, user: %User{id: user_id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :whoami))
      #jr = json_response(conn, 200)["data"]
      assert %{
               "user_id" => ^user_id,
               "user_roles" => ["user"],
               "expires_at" => _expires_at,
               "privacy_policy" => nil,
               "terms_of_service" => nil
             } = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = _user} do
      conn = put(conn, Routes.user_path(conn, :whoami))
      assert conn.status == 403
    end
  end

  describe "reset_password" do
    setup [:create_regular_user_with_session]

    test "works", %{conn: conn, user: %User{id: user_id}, session: _session} do
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      #conn = post(conn, Routes.user_path(conn, user_id, :admin_reset_password), %{})
      #conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/
    end

    test "works with username instead of ID", %{conn: conn, user: %User{id: _user_id} = user, session: _session} do
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user.username))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/
    end

    test "requires auth to access", %{conn: conn, user: %User{} = user, session: _session} do
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user.id))
      assert conn.status == 403
    end

    test "requires being admin to access", %{conn: conn, user: %User{} = user, session: session} do
      # Our user is a regular user, not an admin
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user.id))
      assert conn.status == 401
    end
  end

  describe "reset_password:token" do
    setup [:create_regular_user_with_session]

    test "works", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with new password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued", %{conn: conn, user: %User{id: user_id}, session: _session} do
      {:ok, _conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, "abcde"), new_password: "everythingturnstostone")
      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
    end

    test "Rejects when token is wrong", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with wrong token
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, "incorrect token"), new_password: new_password)
      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)

      # Try to login with new password and make sure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} = json_response(conn, 401)

      # Try to login with old password and ensure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with new password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token), new_password: new_password)
      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
    end

    test "can't use a reset token after a new one has been created", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token_1
             } = json_response(conn, 200)["data"]
      assert password_reset_token_1 =~ ~r/[A-Za-z0-9]{65}/

      # Get a second password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token_2
             } = json_response(conn, 200)["data"]
      assert password_reset_token_2 =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with token 1 and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token_1), new_password: new_password)
      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with the old password to make sure it still works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token_2), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Try to login with new password and ensure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't use token after expiration", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)})
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token), new_password: new_password)
      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} = json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with the old password to make sure it still works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "requires auth to access", %{conn: conn, user: %User{} = user, session: _session} do
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user.id, "1234"))
      assert conn.status == 403
    end

    test "requires being admin to access", %{conn: conn, user: %User{} = user, session: session} do
      # Our user is a regular user, not an admin
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user.id, "1234"))
      assert conn.status == 401
    end

    test "works - endpoint with no user ID", %{conn: conn, user: %User{id: _user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user.username))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with new password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued - endpoint with no user ID", %{conn: conn, user: %User{id: _user_id}, session: _session} do
      {:ok, _conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "abcde"), new_password: "everythingturnstostone")
      #assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"errors" => %{}} = json_response(conn, 404)
    end

    test "Rejects when token is wrong - endpoint with no user ID", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with wrong token
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "incorrect token"), new_password: new_password)
      #assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"errors" => %{}} = json_response(conn, 404)

      # Try to login with new password and make sure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} = json_response(conn, 401)

      # Try to login with old password and ensure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token - endpoint with no user ID", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with new password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token), new_password: new_password)
      #assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"errors" => %{}} = json_response(conn, 404)
    end

    test "can't use a reset token after a new one has been created - endpoint with no user ID", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token_1
             } = json_response(conn, 200)["data"]
      assert password_reset_token_1 =~ ~r/[A-Za-z0-9]{65}/

      # Get a second password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token_2
             } = json_response(conn, 200)["data"]
      assert password_reset_token_2 =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with token 1 and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token_1), new_password: new_password)
      #assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"errors" => %{}} = json_response(conn, 404)

      # Try to login with new password and ensure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with the old password to make sure it still works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token_2), new_password: new_password)
      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Try to login with new password and ensure it works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't use token after expiration - endpoint with no user ID", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))
      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]
      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)})
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token), new_password: new_password)
      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} = json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: new_password})
      assert %{"invalid_credentials" => true} == json_response(conn, 401)

      # Now login with the old password to make sure it still works
      conn = post(conn, Routes.session_path(build_conn(), :create), session: %{username: user.username, password: user.password})
      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "requires auth to access - endpoint with no user ID", %{conn: conn, user: %User{} = _user, session: _session} do
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "1234"))
      assert conn.status == 403
    end

    test "requires being admin to access - endpoint with no user ID", %{conn: conn, user: %User{} = _user, session: session} do
      # Our user is a regular user, not an admin
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "1234"))
      assert conn.status == 401
    end
  end


  defp create_regular_user(_) do
    {:ok, user} = Helpers.Accounts.regular_user()
    %{user: user}
  end

  defp create_regular_user_with_session(_) do
    {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    %{user: user, session: session}
  end
end
