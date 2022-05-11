defmodule MalanWeb.UserControllerTest do
  use MalanWeb.ConnCase, async: true

  # import Swoosh.TestAssertions, only: [assert_email_sent: 0, assert_email_sent: 1]

  alias Malan.Accounts
  alias Malan.Accounts.{User, Session, Transaction}
  alias Malan.Utils
  alias Malan.Repo

  alias Malan.Test.Helpers
  alias Malan.Test.Utils, as: TestUtils

  # alias MalanWeb.UserNotifier

  @create_attrs %{
    email: "some@email.com",
    username: "someusername",
    first_name: "Some",
    last_name: "cool User",
    custom_attrs: %{"hereiam" => "rockyou", "likea" => "hurricane", "year" => 1986},
    birthday: "1986-06-13",
    locked_at: ""  # Shouldn't make it through
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

  def returned_to_orig(ret_users) when is_list(ret_users) do
    ret_users
    |> Enum.map(fn u -> returned_to_orig(u) end)
  end

  def returned_to_orig(ret_user) do
    ret_user
    |> Utils.map_string_keys_to_atoms()
    |> Enum.reject(fn {k, _v} -> k == "preferences" end)
    |> Enum.reject(fn {k, _v} -> k == "password" end)
    |> Enum.into(%{})
  end

  def orig_to_retval(orig_users) when is_list(orig_users) do
    orig_users
    |> Enum.map(fn u -> orig_to_retval(u) end)
  end

  def orig_to_retval(orig_user) do
    orig_user
    |> Utils.struct_to_map()
    |> Utils.map_atom_keys_to_strings()
    |> strip_user()
  end

  defp strip_user(user) do
    user
    |> Enum.reject(fn {k, _v} -> k == "race" end)
    |> Enum.reject(fn {k, _v} -> k == "password" end)
    |> Enum.reject(fn {k, _v} -> k == "sex_enum" end)
    |> Enum.reject(fn {k, _v} -> k == "race_enum" end)
    |> Enum.reject(fn {k, _v} -> k == "addresses" end)
    |> Enum.reject(fn {k, _v} -> k == "updated_at" end)
    |> Enum.reject(fn {k, _v} -> k == "accept_tos" end)
    |> Enum.reject(fn {k, _v} -> k == "deleted_at" end)
    |> Enum.reject(fn {k, _v} -> k == "gender_enum" end)
    |> Enum.reject(fn {k, _v} -> k == "middle_name" end)
    |> Enum.reject(fn {k, _v} -> k == "name_prefix" end)
    |> Enum.reject(fn {k, _v} -> k == "name_suffix" end)
    |> Enum.reject(fn {k, _v} -> k == "inserted_at" end)
    |> Enum.reject(fn {k, _v} -> k == "preferences" end)
    |> Enum.reject(fn {k, _v} -> k == "display_name" end)
    |> Enum.reject(fn {k, _v} -> k == "tos_accepted" end)
    |> Enum.reject(fn {k, _v} -> k == "custom_attrs" end)
    |> Enum.reject(fn {k, _v} -> k == "phone_numbers" end)
    |> Enum.reject(fn {k, _v} -> k == "password_hash" end)
    |> Enum.reject(fn {k, _v} -> k == "ethnicity_enum" end)
    |> Enum.reject(fn {k, _v} -> k == "reset_password" end)
    |> Enum.reject(fn {k, _v} -> k == "password_reset_token" end)
    |> Enum.reject(fn {k, _v} -> k == "accept_privacy_policy" end)
    |> Enum.reject(fn {k, _v} -> k == "privacy_policy_accepted" end)
    |> Enum.reject(fn {k, _v} -> k == "password_reset_token_hash" end)
    |> Enum.reject(fn {k, _v} -> k == "password_reset_token_expires_at" end)
    |> Enum.into(%{})
  end

  def assert_list_users_eq(l1, l2) do
    assert Enum.count(l1) == Enum.count(l2)

    l1 = Enum.map(l1, fn u -> strip_user(u) end)
    l2 = Enum.map(l2, fn u -> strip_user(u) end)

    l1
    |> Enum.with_index()
    |> Enum.each(fn {u, i} -> assert u == Enum.at(l2, i) end)
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "show" do
    setup [:create_regular_user_with_session]

    test "Rejects with 403 when expired", %{
      conn: conn,
      user: %User{id: id} = _user,
      session: %Session{} = session
    } do
      session = Helpers.Accounts.set_expired(session)
      assert TestUtils.DateTime.within_last?(session.expires_at, 20, :seconds)

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => "API token is expired or revoked",
               "token_expired" => true
             } = json_response(conn, 403)
    end

    test "Rejects with 403 when revoked", %{
      conn: conn,
      user: %User{id: id} = _user,
      session: %Session{} = session
    } do
      assert is_nil(session.revoked_at)
      session = Helpers.Accounts.set_revoked(session)
      assert true == TestUtils.DateTime.within_last?(session.revoked_at, 12, :seconds)

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => "API token is expired or revoked",
               "token_expired" => true
             } = json_response(conn, 403)
    end
  end

  describe "index" do
    test "lists all users (as admin)", %{conn: conn} do
      {:ok, conn, au, _as} = Helpers.Accounts.admin_user_session_conn(conn)
      {:ok, ru, _rs} = Helpers.Accounts.regular_user_with_session()
      conn = get(conn, Routes.user_path(conn, :index))
      users = json_response(conn, 200)["data"]

      assert Enum.any?(users, fn u ->
               u["id"] == au.id &&
                 u["email"] == au.email &&
                 u["first_name"] == au.first_name &&
                 u["last_name"] == au.last_name &&
                 u["nick_name"] == au.nick_name &&
                 u["roles"] == au.roles &&
                 u["sex"] == au.sex
             end)

      assert Enum.any?(users, fn u ->
               u["id"] == ru.id &&
                 u["email"] == ru.email &&
                 u["first_name"] == ru.first_name &&
                 u["last_name"] == ru.last_name &&
                 u["nick_name"] == ru.nick_name &&
                 u["roles"] == ru.roles
             end)
    end

    test "requires being an admin to access (unauthenticated)", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :index))

      assert %{
        "ok" => false,
        "code" => 403,
        "detail" => "Forbidden",
        "message" => "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
      } == json_response(conn, 403)
    end

    test "requires being an admin to access (as regular user)", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, rs.api_token)
      conn = get(conn, Routes.user_path(conn, :index))

      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => "You are authenticated but do not have access to this method on this object."
      } == json_response(conn, 401)
    end

    test "requires being an admin to access (as moderator)", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.moderator_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.user_path(conn, :index))

      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => "You are authenticated but do not have access to this method on this object."
      } == json_response(conn, 401)
    end

    test "Works with pagination (as admin)", %{conn: conn} do
      #
      # Note:  This is a little flakey D-:
      # The return order is not totally deterministic due to race conditions
      # and the fact that users controller index doesn't sort (ORDER BY) the
      # results.
      #
      # As users don't have a good way to sort, may want to change the test
      # to instead make sure that all 6 (8 including the root user and au)
      # come back on different pages. Each page has unique users, no user
      # shows up more than once.
      #
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)
      {:ok, u1} = Helpers.Accounts.regular_user()
      {:ok, u2} = Helpers.Accounts.regular_user()
      {:ok, u3} = Helpers.Accounts.regular_user()
      {:ok, u4} = Helpers.Accounts.regular_user()
      {:ok, u5} = Helpers.Accounts.regular_user()
      {:ok, u6} = Helpers.Accounts.regular_user()

      conn = get(conn, Routes.user_path(conn, :index), %{page_num: 1, page_size: 2})
      resp = json_response(conn, 200)
      assert 1 == resp["page_num"]
      assert 2 == resp["page_size"]
      assert_list_users_eq(orig_to_retval([u1, u2]), resp["data"])

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.user_path(conn, :index), %{page_num: 2, page_size: 2})
      resp = json_response(conn, 200)
      assert 2 == resp["page_num"]
      assert 2 == resp["page_size"]
      assert_list_users_eq(orig_to_retval([u3, u4]), resp["data"])

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.user_path(conn, :index), %{page_num: 3, page_size: 2})
      resp = json_response(conn, 200)
      assert 3 == resp["page_num"]
      assert 2 == resp["page_size"]
      assert_list_users_eq(orig_to_retval([u5, u6]), resp["data"])

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.user_path(conn, :index), %{page_num: 4, page_size: 2})
      resp = json_response(conn, 200)
      assert 4 == resp["page_num"]
      assert 2 == resp["page_size"]
      assert_list_users_eq(orig_to_retval([]), resp["data"])
    end
  end

  describe "create" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} =
               user = json_response(conn, 201)["data"]

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
               "locked_at" => nil,
               "locked_by" => nil,
               "custom_attrs" => %{
                 "hereiam" => "rockyou",
                 "likea" => "hurricane",
                 "year" => 1986
               }
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false

      # Should not have phone numbers present because not set and not requested
      assert Map.has_key?(jr, "phone_numbers") == false

      # Should not have addresses present because not set and not requested
      assert Map.has_key?(jr, "addresses") == false
    end

    test "allows setting preferences and middle name/display name in creation", %{conn: conn} do
      %{preferences: preferences} =
        create_attrs =
        Map.merge(@create_attrs, %{
          display_name: "Cool display name",
          middle_name: "Von Daesterschpleck",
          name_prefix: "The Honroable Good Doctor",
          name_suffix: "PhD in Doctoral Studies",
          preferences: %{
            theme: "dark",
            display_name_pref: "custom",
            display_middle_initial_only: false
          }
        })

      conn = post(conn, Routes.user_path(conn, :create), user: create_attrs)

      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} =
               user = json_response(conn, 201)["data"]

      assert is_nil(password) == false

      # This uses the returned password above to authenticate
      {:ok, session} = Helpers.Accounts.create_session(Utils.map_string_keys_to_atoms(user))
      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id), abbr: 1)
      jr = json_response(conn, 200)["data"]

      preferences = Utils.map_atom_keys_to_strings(preferences)

      assert %{
               "id" => ^id,
               "email" => "some@email.com",
               "preferences" => ^preferences
             } = jr
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)

      assert json_response(conn, 422) == %{
               "ok" => false,
               "code" => 422,
               "detail" => "Unprocessable Entity",
               "message" =>
                 "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details",
               "errors" => %{
                 "email" => ["can't be blank"],
                 "first_name" => ["can't be blank"],
                 "last_name" => ["can't be blank"],
                 "password_hash" => ["can't be blank"],
                 "username" => ["can't be blank"]
               }
             }
    end

    test "allows specifying initial password and requires ToS/PP", %{conn: conn} do
      password = "initialpassword"

      conn =
        post(conn, Routes.user_path(conn, :create),
          user: Map.put(@create_attrs, :password, password)
        )

      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => ^password} =
               user = json_response(conn, 201)["data"]

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
               "privacy_policy_accepted" => false
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
    end

    test "Accepts phone numbers", %{conn: conn} do
      %{phone_numbers: [%{} = ph1, %{} = ph2]} =
        phone_numbers = %{
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
            }
          ]
        }

      conn =
        post(conn, Routes.user_path(conn, :create), user: Map.merge(@create_attrs, phone_numbers))

      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} =
               user = json_response(conn, 201)["data"]

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
                 "year" => 1986
               },
               "phone_numbers" => phs
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
      assert Enum.count(phs) == 2

      assert Enum.all?(phs, fn ph ->
               ph["number"] == ph1["number"] || ph["number"] == ph2["number"]
             end)
    end

    test "Accepts addresses and phone numbers together", %{conn: conn} do
      %{phone_numbers: [%{} = ph1, %{} = ph2]} =
        phone_numbers = %{
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
            }
          ]
        }

      %{addresses: [%{} = ad1, %{} = ad2]} =
        addresses = %{
          addresses: [
            %{
              "city" => "some city 1",
              "country" => "some country 1",
              "line_1" => "some line_1 1",
              "line_2" => "some line_2 1",
              "name" => "some name 1",
              "postal" => "some postal 1",
              "primary" => true,
              "state" => "some state 1",
              "verified_at" => ~U[2021-12-19 01:54:00Z]
            },
            %{
              "city" => "some city 2",
              "country" => "some country 2",
              "line_1" => "some line_1 2",
              "line_2" => "some line_2 2",
              "name" => "some name 2",
              "postal" => "some postal 2",
              "primary" => true,
              "state" => "some state 2",
              "verified_at" => ~U[2021-12-19 01:54:00Z]
            }
          ]
        }

      _user_attrs =
        @create_attrs
        |> Map.merge(phone_numbers)
        |> Map.merge(addresses)

      conn =
        post(conn, Routes.user_path(conn, :create),
          user: @create_attrs |> Map.merge(phone_numbers) |> Map.merge(addresses)
        )

      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => password} =
               user = json_response(conn, 201)["data"]

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
                 "year" => 1986
               },
               "phone_numbers" => phs,
               "addresses" => addrs
             } = jr

      # password should not be included in get response
      assert Map.has_key?(jr, "password") == false
      assert Enum.count(phs) == 2

      assert Enum.all?(phs, fn ph ->
               ph["number"] == ph1["number"] || ph["number"] == ph2["number"]
             end)

      assert Enum.count(addrs) == 2
      assert Enum.all?(addrs, fn ad -> ad["city"] == ad1["city"] || ad["city"] == ad2["city"] end)

      assert Enum.all?(addrs, fn ad ->
               ad["country"] == ad1["country"] || ad["country"] == ad2["country"]
             end)

      assert Enum.all?(addrs, fn ad ->
               ad["line_1"] == ad1["line_1"] || ad["line_1"] == ad2["line_1"]
             end)

      assert Enum.all?(addrs, fn ad ->
               ad["line_2"] == ad1["line_2"] || ad["line_2"] == ad2["line_2"]
             end)

      assert Enum.all?(addrs, fn ad ->
               ad["state"] == ad1["state"] || ad["state"] == ad2["state"]
             end)

      assert Enum.all?(addrs, fn ad ->
               ad["postal"] == ad1["postal"] || ad["postal"] == ad2["postal"]
             end)

      assert Enum.all?(addrs, fn ad ->
               ad["primary"] == ad1["primary"] || ad["primary"] == ad2["primary"]
             end)

      assert Enum.all?(addrs, fn ad -> ad["name"] == ad1["name"] || ad["name"] == ad2["name"] end)
    end

    test "Creates a corresponding Transaction", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      # password should be included after creation
      assert %{"id" => id} = json_response(conn, 201)["data"]

      assert [
               %Transaction{
                 success: true,
                 user_id: nil,
                 session_id: nil,
                 type_enum: 0,
                 verb_enum: 1,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end

    test "Creates a transaction when create fails. Can't create user with a username that is already taken",
         %{conn: conn} do
      # {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      {:ok, %{username: username} = _user} = Helpers.Accounts.regular_user()

      duplicate_username_attrs = Map.merge(@create_attrs, %{username: username})

      conn = post(conn, Routes.user_path(conn, :create), user: duplicate_username_attrs)
      # password should be included after creation
      assert 422 == conn.status

      assert [
               %Transaction{
                 success: false,
                 user_id: nil,
                 session_id: nil,
                 type_enum: 0,
                 verb_enum: 1,
                 who: nil,
                 who_username: ^username,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(nil, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(nil, 0, 10)
    end

    test "Accepts approved_ips", %{conn: conn} do
      %{approved_ips: ips} =
        approved_ips = %{
          approved_ips: [
            "127.0.0.1",
            "192.168.1.1",
            "1.1.1.1"
          ]
        }

      create_attrs = Map.merge(@create_attrs, approved_ips)

      conn = post(conn, Routes.user_path(conn, :create), user: create_attrs)

      # password should be included after creation
      assert %{"id" => id, "username" => _username, "password" => _password} =
               user = json_response(conn, 201)["data"]

      # This uses the returned password above to authenticate
      {:ok, session} =
        Helpers.Accounts.create_session(Utils.map_string_keys_to_atoms(user), %{}, "192.168.1.1")

      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))
      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "email" => "some@email.com",
               "email_verified" => nil,
               "approved_ips" => ^ips
             } = jr
    end

    test "Reject session if not approved IP", %{conn: conn} do
      # This test might be duplicated by create session_controller_test
      # And might be more appropriate there
      approved_ips = %{
        approved_ips: [
          "127.0.0.1",
          "192.168.1.1"
        ]
      }

      create_attrs = Map.merge(@create_attrs, approved_ips)

      conn = post(conn, Routes.user_path(conn, :create), user: create_attrs)

      # password should be included after creation
      assert user = json_response(conn, 201)["data"]

      # This uses the returned password above to authenticate
      {:error, :unauthorized} =
        Helpers.Accounts.create_session(
          Utils.map_string_keys_to_atoms(user),
          %{},
          "192.168.1.109"
        )
    end
  end

  describe "update user" do
    setup [:create_regular_user_with_session]

    test "allows updating password, preferences, nickname, and accepting ToS and privacy policy",
         %{conn: conn, user: %User{id: id} = user, session: session} do
      update_params = %{
        nick_name: "Eddie van Halen",
        accept_tos: true,
        accept_privacy_policy: true,
        preferences: %{theme: "dark"},
        sex: "male",
        birthday: ~D[1986-06-13],
        roles: ["admin", "user"],  # Shouldn't make it through
        custom_attrs: %{
          "hereiam" => "rockyou",
          "likea" => "hurricane",
          "year" => 1986
        }
      }

      check_response = fn conn ->
        assert %{
                 "id" => ^id,
                 "email" => email,
                 "username" => username,
                 "email_verified" => nil,
                 "preferences" => %{"theme" => "dark"},
                 "roles" => ["user"],
                 "birthday" => "1986-06-13",
                 "sex" => "Male",
                 "gender" => nil,
                 "latest_tos_accept_ver" => 1,
                 "latest_pp_accept_ver" => 1,
                 "tos_accepted" => true,
                 "privacy_policy_accepted" => true,
                 "tos_accept_events" => [
                   %{
                     "accept" => true,
                     "tos_version" => 1,
                     "timestamp" => tostimestamp
                   }
                 ],
                 "privacy_policy_accept_events" => [
                   %{
                     "accept" => true,
                     "privacy_policy_version" => 1,
                     "timestamp" => pptimestamp
                   }
                 ],
                 "nick_name" => "Eddie van Halen",
                 "custom_attrs" => %{
                   "hereiam" => "rockyou",
                   "likea" => "hurricane",
                   "year" => 1986
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

    test "allows using username instead of user ID", %{
      conn: conn,
      user: %User{id: id, email: email, username: username},
      session: session
    } do
      %{nick_name: nick_name} = update_params = %{nick_name: "Eddie van Halen"}

      check_response = fn conn ->
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

    test "renders errors when data is invalid", %{
      conn: conn,
      user: %User{} = user,
      session: session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: @invalid_attrs)

      assert json_response(conn, 422) == %{
               "ok" => false,
               "code" => 422,
               "detail" => "Unprocessable Entity",
               "message" =>
                 "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details",
               "errors" => %{
                 "preferences" => ["can't be blank"]
               }
             }
    end

    test "allows updating password", %{conn: conn, user: %User{id: id} = user} do
      # authenticate with first password, then change it,
      # then authenticate with the new password
      update_params = %{
        password: "rockyoulikeahurricane"
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

      assert {:ok, session} =
               Helpers.Accounts.create_session(%{user | password: "rockyoulikeahurricane"})

      conn = Helpers.Accounts.put_token(Phoenix.ConnTest.build_conn(), session.api_token)
      conn = put(conn, Routes.user_path(conn, :update, user), user: %{nick_name: "ronaldo"})
      assert %{"nick_name" => "ronaldo"} = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: %{nick_name: "ohai"})
      assert conn.status == 403
    end

    test "requires being self or admin", %{conn: conn, user: %User{} = user} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      {:ok, _ru, rs} =
        Helpers.Accounts.regular_user_with_session(%{email: "e1@mail.com", username: "e1abcdefg"})

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
          "White"
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
                 "White"
               ]
             } = json_response(conn, 200)["data"]
    end

    test "requires being an admin to access (as regular user)", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, rs.api_token)
      conn = get(conn, Routes.user_path(conn, :index))

      assert %{
        "ok" => false,
        "code" => 401,
        "detail" => "Unauthorized",
        "message" => "You are authenticated but do not have access to this method on this object."
      } == json_response(conn, 401)
    end

    test "Allows updating phone numbers", %{conn: conn, user: %User{} = user} do
      %{phone_numbers: [%{} = ph1, %{} = ph2, %{} = ph3, %{} = ph4]} =
        phone_numbers = %{
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
            }
          ]
        }

      {_user_id, username, email, nick_name} =
        {user.id, user.username, user.email, user.nick_name}

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

      assert Enum.all?(phs, fn ph ->
               [ph1, ph2, ph3, ph4]
               |> Enum.map(fn phx -> phx["number"] end)
               |> Enum.member?(ph["number"])
             end)
    end

    test "Accepts approved_ips", %{conn: conn, user: %User{} = user} do
      %{approved_ips: ips} =
        approved_ips = %{
          approved_ips: [
            "127.0.0.1",
            "192.168.1.1"
          ]
        }

      email = user.email

      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      # conn = put(conn, Routes.user_path(conn, :update, user), user: phone_numbers)
      conn = put(conn, Routes.user_path(conn, :update, user), user: approved_ips)

      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))
      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "email" => ^email,
               "approved_ips" => ^ips
             } = jr
    end

    test "disallows setting roles", %{conn: conn, user: %User{} = user, session: session} do
      id = user.id

      update_params = %{
        roles: ["admin", "user", "smileemptysoul"],  # Shouldn't make it through
      }

      check_response = fn conn ->
        assert %{
                 "roles" => ["user"]
               } = json_response(conn, 200)["data"]
      end

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "roles" => ["user"]
             } = json_response(conn, 200)["data"]

      conn = put(conn, Routes.user_path(conn, :update, user), user: update_params)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      check_response.(conn)

      conn = get(conn, Routes.user_path(conn, :show, id))
      check_response.(conn)
    end

    test "Creates a corresponding Transaction", %{
      conn: conn,
      user: %User{id: id} = user,
      session: %Session{id: session_id} = session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn = put(conn, Routes.user_path(conn, :update, user), user: %{nick_name: "Danny Carey"})

      assert %{
               "id" => ^id,
               "nick_name" => "Danny Carey"
             } = json_response(conn, 200)["data"]

      assert [
               %Transaction{
                 success: true,
                 user_id: ^id,
                 session_id: ^session_id,
                 type_enum: 0,
                 verb_enum: 2,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(session_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end

    test "Accepts datetimes and more precision on birthday", %{conn: conn, user: %User{} = user} do
      email = user.email

      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      [
        "2022-05-11 01:30:49.970337Z",
        "2022-05-11 01:30:49.00000",
        "2022-05-11 01:30:49.00",
        "2022-05-11 01:30:49",
        "2022-05-11"
      ]
      |> Enum.each(fn datetime ->
        conn = put(conn, Routes.user_path(conn, :update, user), user: %{birthday: datetime})

        assert %{"id" => id} = json_response(conn, 200)["data"]

        conn = get(conn, Routes.user_path(conn, :show, id))

        assert %{
                 # "ok" => true,
                 # "code" => 200,
                 "data" => %{
                   "id" => ^id,
                   "email" => ^email,
                   "birthday" => "2022-05-11"
                 }
               } = json_response(conn, 200)
      end)
    end

    test "Rejects malformed birthdays", %{conn: conn, user: %User{} = user} do
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      [
        "2022-05-11 01:30",
        "2022-05-11 01",
        "2022-05",
        "false",
        "4.567",
        "2022",
        "null",
        "abc",
        "nil"
      ]
      |> Enum.each(fn datetime ->
        conn = put(conn, Routes.user_path(conn, :update, user), user: %{birthday: datetime})

        assert %{
                 "ok" => false,
                 "code" => 422,
                 "detail" => "Unprocessable Entity",
                 "message" =>
                   "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details",
                 "errors" => %{
                   "birthday" => ["is invalid"]
                 }
               } = json_response(conn, 422)
      end)
    end
  end

  describe "admin update user" do
    setup [:create_regular_user_with_session]

    test "allows updating roles, password, preferences, nickname, and accepting ToS and privacy policy",
         %{conn: conn, user: %User{id: id} = user, session: session} do
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
        ethnicity: "Hispanic or Latinx"
      }

      check_response = fn conn ->
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
                 "race" => ["Asian", "White"]
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

      # {:ok, _au1, as1} = Helpers.Accounts.admin_user_with_session()
      # {:ok, au2, _as2} = Helpers.Accounts.admin_user_with_session(%{email: "au2@mail.com", username: "au2"})
      # conn = Helpers.Accounts.put_token(conn, as1.api_token)
      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["admin", "user"]} = json_response(conn, 200)["data"]
      conn = put(conn, Routes.user_path(conn, :admin_update, au2.id), user: %{roles: ["user"]})
      assert %{"roles" => ["user"]} = json_response(conn, 200)["data"]
      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["user"]} = json_response(conn, 200)["data"]
    end

    test "allows setting arbitrary roles", %{conn: conn, user: %User{}, session: _session} do
      [{:ok, conn, _au1, _as1}, {:ok, _conn, au2, _as2}] =
        Helpers.Accounts.admin_users_session_conn(conn, 2)

      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["admin", "user"]} = json_response(conn, 200)["data"]

      conn =
        put(conn, Routes.user_path(conn, :admin_update, au2.id),
          user: %{roles: ["user", "helloworld"]}
        )

      assert %{"roles" => ["user", "helloworld"]} = json_response(conn, 200)["data"]
      conn = get(conn, Routes.user_path(conn, :show, au2.id))
      assert %{"roles" => ["user", "helloworld"]} = json_response(conn, 200)["data"]
    end

    test "Allows updating phone numbers", %{conn: _conn, user: %User{} = user} do
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(build_conn())

      %{phone_numbers: [%{} = ph1, %{} = ph2, %{} = ph3, %{} = ph4]} =
        phone_numbers = %{
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
            }
          ]
        }

      {_user_id, username, email, nick_name} =
        {user.id, user.username, user.email, user.nick_name}

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

      assert Enum.all?(phs, fn ph ->
               [ph1, ph2, ph3, ph4]
               |> Enum.map(fn phx -> phx["number"] end)
               |> Enum.member?(ph["number"])
             end)
    end

    test "Creates a corresponding transaction", %{
      conn: _conn,
      user: %User{id: id} = user,
      session: %Session{} = _session
    } do
      {:ok, conn, %{id: admin_user_id} = _au, %{id: admin_session_id} = _as} =
        Helpers.Accounts.admin_user_session_conn(build_conn())

      conn =
        put(conn, Routes.user_path(conn, :admin_update, user), user: %{roles: ["admin", "user"]})

      assert %{
               "id" => ^id,
               "roles" => ["admin", "user"]
             } = json_response(conn, 200)["data"]

      assert [
               %Transaction{
                 success: true,
                 user_id: ^admin_user_id,
                 session_id: ^admin_session_id,
                 type_enum: 0,
                 verb_enum: 2,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(admin_user_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(admin_session_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end
  end

  describe "delete user" do
    setup [:create_regular_user_with_session]

    test "marks user as deleted", %{conn: conn, user: user, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      conn = get(conn, Routes.user_path(conn, :show, user))

      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "Creates a corresponding transaction", %{
      conn: conn,
      user: %User{id: id} = user,
      session: %Session{id: session_id} = session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      conn = get(conn, Routes.user_path(conn, :show, user))

      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)

      assert [
               %Transaction{
                 success: true,
                 user_id: ^id,
                 session_id: ^session_id,
                 type_enum: 0,
                 verb_enum: 3,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(session_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end
  end

  # Deprecated in favor of "current"
  describe "me" do
    setup [:create_regular_user_with_session]

    test "Retrieves all user info based on API token", %{
      conn: conn,
      user: %User{id: user_id},
      session: session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :me))

      assert %{
               "id" => ^user_id,
               "roles" => ["user"],
               "username" => _username,
               "nick_name" => _nick_name
             } = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = _user} do
      conn = put(conn, Routes.user_path(conn, :me))
      assert conn.status == 403
    end
  end

  describe "current" do
    setup [:create_regular_user_with_session]

    test "Retrieves all user info based on API token", %{
      conn: conn,
      user: %User{id: user_id},
      session: session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :current))

      assert %{
               "id" => ^user_id,
               "roles" => ["user"],
               "username" => _username,
               "nick_name" => _nick_name
             } = json_response(conn, 200)["data"]
    end

    test "requires being authenticated to access", %{conn: conn, user: %User{} = _user} do
      conn = put(conn, Routes.user_path(conn, :current))
      assert conn.status == 403
    end
  end

  describe "whoami" do
    setup [:create_regular_user_with_session]

    test "Retrieves user ID and roles based on API token", %{
      conn: conn,
      user: %User{id: user_id},
      session: session
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :whoami))
      # jr = json_response(conn, 200)["data"]
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

    test "Rejects with 403 when expired", %{
      conn: conn,
      user: %User{} = _user,
      session: %Session{} = session
    } do
      assert not Accounts.session_expired?(session)
      session = Helpers.Accounts.set_expired(session)
      assert Accounts.session_expired?(session)

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :whoami))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => "API token is expired or revoked",
               "token_expired" => true
             } = json_response(conn, 403)
    end

    test "Rejects with 403 when revoked", %{
      conn: conn,
      user: %User{} = _user,
      session: %Session{} = session
    } do
      assert is_nil(session.revoked_at)
      session = Helpers.Accounts.set_revoked(session)
      assert not is_nil(session.revoked_at)

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :whoami))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => "API token is expired or revoked",
               "token_expired" => true
             } = json_response(conn, 403)
    end
  end

  describe "reset_password" do
    setup [:create_regular_user_with_session]

    test "works without auth", %{user: %User{id: user_id}} do
      conn = build_conn()
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Check that an email was sent to the user with the token
    end

    test "works with username instead of ID", %{
      conn: conn,
      user: %User{id: _user_id} = user,
      session: _session
    } do
      conn = post(conn, Routes.user_path(conn, :reset_password, user.username))

      assert %{"ok" => true} = json_response(conn, 200)

      # Check that an email was sent to the user with the token
    end

    test "Returns 404 when user is not found", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :reset_password, "invaliduser"))

      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "Creates a corresponding transaction", %{conn: conn, user: %User{id: id}} do
      conn = post(conn, Routes.user_path(conn, :reset_password, id))

      assert conn.status == 200

      assert [
               %Transaction{
                 success: true,
                 user_id: nil,
                 session_id: nil,
                 type_enum: 0,
                 verb_enum: 1,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(nil, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end
  end

  describe "reset_password:token" do
    setup [:create_regular_user_with_session]

    test "works", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second trigger a password reset email
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))
      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued", %{
      conn: conn,
      user: %User{id: user_id}
    } do
      # conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :reset_password_token_user, user_id, "abcde"),
          new_password: "everythingturnstostone"
        )

      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} =
               json_response(conn, 401)
    end

    test "Rejects when token is wrong", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # Get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))
      assert %{"ok" => true} = json_response(conn, 200)

      # Now try to change password with wrong token
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, user_id, "incorrect token"),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and make sure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with old password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} =
               json_response(conn, 401)
    end

    test "can't use a reset token after a new one has been created", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token_1}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token_1 =~ ~r/[A-Za-z0-9]{65}/

      # Clear rate limit bucket so we can request a new token without waiting
      Malan.RateLimits.PasswordReset.clear(user_id)

      # Get a second password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token_2}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token_2 =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with token 1 and make sure it fails
      conn =
        put(
          conn,
          Routes.user_path(
            conn,
            :reset_password_token_user,
            user_id,
            password_reset_token_1
          ),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn =
        put(
          conn,
          Routes.user_path(
            conn,
            :reset_password_token_user,
            user_id,
            password_reset_token_2
          ),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with new password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "password reset endpoint rate limits requests", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Get a second password reset token.  This should get rate limited
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => false, "code" => 429, "detail" => "Too Many Requests"} =
               json_response(conn, 429)

      # Try a third time.  Still rate limited
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => false, "code" => 429, "detail" => "Too Many Requests"} =
               json_response(conn, 429)
    end

    test "can't use token after expiration", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{
        password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)
      })
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "works - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: _user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user.username))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: _user_id},
      session: _session
    } do
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, "abcde"),
          new_password: "everythingturnstostone"
        )

      # assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "Rejects when token is wrong - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with wrong token
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, "incorrect token"),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)

      # Try to login with new password and make sure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with old password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "can't use a reset token after a new one has been created - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token_1}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token_1 =~ ~r/[A-Za-z0-9]{65}/

      # Clear rate limit bucket so we can request a new token without waiting
      Malan.RateLimits.PasswordReset.clear(user_id)

      # Get a second password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token_2}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token_2 =~ ~r/[A-Za-z0-9]{65}/

      # Now try to change password with token 1 and make sure it fails
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token_1),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token_2),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with new password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't use token after expiration - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, user_id))

      assert %{"ok" => true} = json_response(conn, 200)

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{
        password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)
      })
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn =
        put(conn, Routes.user_path(conn, :reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Creates a corresponding transaction", %{
      conn: conn,
      user: %User{id: id} = user
    } do
      new_password = "bensonwinifredpayne"

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :reset_password, id))
      assert conn.status == 200

      # Retrieve the reset token from the email.
      # The database token is hashed so we can't get it from there.
      %Swoosh.Email{assigns: %{user: %{password_reset_token: password_reset_token}}} =
        assert_and_receive_email(user, "Your requested password reset token")

      assert %{"ok" => true} = json_response(conn, 200)

      # Now change password
      conn =
        put(
          conn,
          Routes.user_path(conn, :reset_password_token_user, id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => true} = json_response(conn, 200)

      # Now check for the corresponding transaction
      match_transaction_extract_when = fn t ->
        try do
          %Transaction{
            success: true,
            user_id: nil,
            session_id: nil,
            type_enum: 0,
            verb_enum: _,
            who: ^id,
            what: _,
            when: when_utc
          } = t

          {:ok, when_utc}
        rescue
          me in MatchError -> {:error, me}
          e in StandardError -> {:error, e}
        end
      end

      trans_by_who = Accounts.list_transactions_by_who(id, 0, 10)
      assert 3 == length(trans_by_who)

      assert Enum.any?(trans_by_who, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)

      trans_by_user_id = Accounts.list_transactions_by_user_id(nil, 0, 10)
      assert 3 == length(trans_by_user_id)

      assert Enum.any?(trans_by_user_id, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)

      trans_by_session_id = Accounts.list_transactions_by_session_id(nil, 0, 10)
      assert 3 == length(trans_by_session_id)

      assert Enum.any?(trans_by_session_id, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)
    end

    test "Creates a Transaction if password reset fails" do
      # TODO
    end
  end

  describe "admin_reset_password:token" do
    setup [:create_regular_user_with_session]

    test "works", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued", %{
      conn: conn,
      user: %User{id: user_id},
      session: _session
    } do
      {:ok, _conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token_user, user_id, "abcde"),
          new_password: "everythingturnstostone"
        )

      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} =
               json_response(conn, 401)
    end

    test "Rejects when token is wrong", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
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

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, user_id, "incorrect token"),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and make sure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with old password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token", %{conn: conn, user: %User{id: user_id} = user, session: _session} do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} =
               json_response(conn, 401)
    end

    test "can't use a reset token after a new one has been created", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

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

      conn =
        put(
          conn,
          Routes.user_path(
            conn,
            :admin_reset_password_token_user,
            user_id,
            password_reset_token_1
          ),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(
            conn,
            :admin_reset_password_token_user,
            user_id,
            password_reset_token_2
          ),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with new password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't use token after expiration", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{
        password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)
      })
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, user_id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

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

    test "works - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: _user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user.username))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "Rejects when no password reset token is issued - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: _user_id},
      session: _session
    } do
      {:ok, _conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, "abcde"),
          new_password: "everythingturnstostone"
        )

      # assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "Rejects when token is wrong - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
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

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, "incorrect token"),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)

      # Try to login with new password and make sure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with old password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't reuse a token - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Try to login with old password and ensure it doesn't work anymore
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with new password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Try to use the reset token again
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "missing_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)
    end

    test "can't use a reset token after a new one has been created - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # First login with password to make sure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

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

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token_1),
          new_password: new_password
        )

      # assert %{"ok" => false, "err" => "invalid_password_reset_token", "msg" => _} = json_response(conn, 401)
      # For now just accept a 404
      assert %{"ok" => false, "code" => 404, "detail" => "Not Found"} = json_response(conn, 404)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      # Now try to change password with token 2 and make sure it succeeds
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token_2),
          new_password: new_password
        )

      assert conn.status == 200
      assert %{"ok" => true} = json_response(conn, 200)

      # Now login with the old password to make sure it no longer works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Try to login with new password and ensure it works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "can't use token after expiration - endpoint with no user ID", %{
      conn: conn,
      user: %User{id: user_id} = user,
      session: _session
    } do
      new_password = "bensonwinifredpayne"
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/

      # Set the expiration time into the past so the token is expired
      Ecto.Changeset.change(user, %{
        password_reset_token_expires_at: Utils.DateTime.adjust_cur_time_trunc(-1, :minutes)
      })
      |> Repo.update()

      # Now try to change password with the token and make sure it fails
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(conn, Routes.user_path(conn, :admin_reset_password_token, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => false, "err" => "expired_password_reset_token", "msg" => _} =
               json_response(conn, 401)

      # Try to login with new password and ensure it doesn't work
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: new_password}
        )

      assert %{"ok" => false, "code" => 403, "detail" => "Forbidden"} = json_response(conn, 403)

      # Now login with the old password to make sure it still works
      conn =
        post(conn, Routes.session_path(build_conn(), :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => _id, "api_token" => _api_token} = json_response(conn, 201)["data"]
    end

    test "requires auth to access - endpoint with no user ID", %{
      conn: conn,
      user: %User{} = _user,
      session: _session
    } do
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "1234"))
      assert conn.status == 403
    end

    test "requires being admin to access - endpoint with no user ID", %{
      conn: conn,
      user: %User{} = _user,
      session: session
    } do
      # Our user is a regular user, not an admin
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :admin_reset_password_token, "1234"))
      assert conn.status == 401
    end

    test "Creates a corresponding transaction", %{
      conn: conn,
      user: %User{id: id} = _user,
      session: %Session{} = _session
    } do
      new_password = "bensonwinifredpayne"

      {:ok, conn, %{id: admin_user_id} = _au, %{id: admin_session_id} = as} =
        Helpers.Accounts.admin_user_session_conn(conn)

      # Second get a password reset token
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, id))
      assert conn.status == 200

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      # Now change password
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      conn =
        put(
          conn,
          Routes.user_path(conn, :admin_reset_password_token_user, id, password_reset_token),
          new_password: new_password
        )

      assert %{"ok" => true} = json_response(conn, 200)

      # Now check for the corresponding transaction
      match_transaction_extract_when = fn t ->
        try do
          %Transaction{
            success: true,
            user_id: ^admin_user_id,
            session_id: ^admin_session_id,
            type_enum: 0,
            verb_enum: 2,
            who: ^id,
            what: "#UserController.admin_reset_password_token/3",
            when: when_utc
          } = t

          {:ok, when_utc}
        rescue
          me in MatchError -> {:error, me}
          e in StandardError -> {:error, e}
        end
      end

      trans_by_who = Accounts.list_transactions_by_who(id, 0, 10)
      assert 3 == length(trans_by_who)

      assert Enum.any?(trans_by_who, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)

      trans_by_user_id = Accounts.list_transactions_by_user_id(admin_user_id, 0, 10)
      assert 2 == length(trans_by_user_id)

      assert Enum.any?(trans_by_user_id, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)

      trans_by_session_id = Accounts.list_transactions_by_session_id(admin_session_id, 0, 10)
      assert 2 == length(trans_by_session_id)

      assert Enum.any?(trans_by_session_id, fn t ->
               case match_transaction_extract_when.(t) do
                 {:ok, when_utc} -> TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
                 {:error, _} -> false
               end
             end)
    end
  end

  describe "admin_reset_password" do
    setup [:create_regular_user_with_session]

    test "works", %{conn: conn, user: %User{id: user_id}, session: _session} do
      {:ok, conn, _au, as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, user_id))

      assert %{
               "password_reset_token" => password_reset_token
             } = json_response(conn, 200)["data"]

      assert password_reset_token =~ ~r/[A-Za-z0-9]{65}/
    end

    test "works with username instead of ID", %{
      conn: conn,
      user: %User{id: _user_id} = user,
      session: _session
    } do
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

    test "Creates a corresponding transaction", %{
      conn: conn,
      user: %User{id: id} = _user,
      session: %Session{} = _session
    } do
      {:ok, conn, %{id: admin_user_id} = _au, %{id: admin_session_id} = as} =
        Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = post(conn, Routes.user_path(conn, :admin_reset_password, id))

      assert conn.status == 200

      assert [
               %Transaction{
                 success: true,
                 user_id: ^admin_user_id,
                 session_id: ^admin_session_id,
                 type_enum: 0,
                 verb_enum: 1,
                 who: ^id,
                 when: when_utc
               } = tx
             ] = Accounts.list_transactions_by_who(id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [tx] == Accounts.list_transactions_by_user_id(admin_user_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_session_id(admin_session_id, 0, 10)
      assert [tx] == Accounts.list_transactions_by_who(id, 0, 10)
    end
  end

  describe "locked" do
    setup [:create_regular_user_with_session]

    test "creates users unlocked", %{conn: conn, user: %User{id: id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "locked_at" => nil,
               "locked_by" => nil
             } = json_response(conn, 200)["data"]

      {:ok, conn, %User{id: admin_id}, as} =
        Helpers.Accounts.admin_user_session_conn(build_conn())

      conn = put(conn, Routes.user_path(conn, :lock, id))

      check_response = fn conn ->
        assert %{
                 "id" => ^id,
                 "locked_at" => locked_at,
                 "locked_by" => ^admin_id
               } = json_response(conn, 200)["data"]

        for ts <- [locked_at] do
          assert {:ok, ts, 0} = DateTime.from_iso8601(ts)
          assert TestUtils.DateTime.within_last?(ts, 5, :seconds) == true
        end
      end

      check_response.(conn)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))
      check_response.(conn)
    end

    test "Must be authenticated", %{conn: conn, user: %User{id: id}} do
      conn = put(conn, Routes.user_path(conn, :lock, id))
      assert conn.status == 403
    end

    test "Must be admin to access", %{conn: conn, user: %User{id: id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :lock, id))
      assert conn.status == 401
    end

    test "Revokes all outstanding tokens", %{
      conn: conn,
      user: %User{id: id, username: username} = user,
      session: session
    } do
      {:ok, _conn, %User{id: admin_id}, admin_session} =
        Helpers.Accounts.admin_user_session_conn(conn)

      sessions =
        1..4
        |> Enum.map(fn _ -> Helpers.Accounts.create_session(user) end)
        |> Enum.map(fn {:ok, s} -> s end)

      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      for s <- sessions do
        assert {:ok, ^id, ^username, _, _, _, _, _, _, _} =
                 Accounts.validate_session(s.api_token, nil)
      end

      assert 5 == Accounts.list_active_sessions(user, 0, 10) |> Enum.count()

      conn = Helpers.Accounts.put_token(build_conn(), admin_session.api_token)
      conn = put(conn, Routes.user_path(conn, :lock, id))

      assert %{
               "id" => ^id,
               "locked_at" => _locked_at,
               "locked_by" => ^admin_id
             } = json_response(conn, 200)["data"]

      # token should now be revoked
      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))
      assert conn.status == 403

      for s <- sessions do
        assert {:error, :revoked} = Accounts.validate_session(s.api_token, nil)
      end

      assert 0 == Accounts.list_active_sessions(user, 0, 10) |> Enum.count()
    end
  end

  describe "unlock" do
    setup [:create_regular_user_with_session]

    test "Works", %{conn: conn, user: %User{id: id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      {:ok, _conn, %User{id: admin_id}, admin_session} =
        Helpers.Accounts.admin_user_session_conn(conn)

      conn = Helpers.Accounts.put_token(build_conn(), admin_session.api_token)
      conn = put(conn, Routes.user_path(conn, :lock, id))

      assert %{
               "id" => ^id,
               "locked_at" => locked_at,
               "locked_by" => ^admin_id
             } = json_response(conn, 200)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), admin_session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{"id" => ^id, "locked_by" => ^admin_id, "locked_at" => ^locked_at} =
               json_response(conn, 200)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), admin_session.api_token)
      conn = put(conn, Routes.user_path(conn, :unlock, id))

      assert %{"id" => ^id, "locked_by" => nil, "locked_at" => nil} =
               json_response(conn, 200)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), admin_session.api_token)
      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{"id" => ^id, "locked_by" => nil, "locked_at" => nil} =
               json_response(conn, 200)["data"]
    end

    test "Must be authenticated", %{conn: conn, user: %User{id: id}} do
      conn = put(conn, Routes.user_path(conn, :unlock, id))
      assert conn.status == 403
    end

    test "Must be admin to access", %{conn: conn, user: %User{id: id}, session: session} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.user_path(conn, :unlock, id))
      assert conn.status == 401
    end
  end

  # defp create_regular_user(_) do
  #   {:ok, user} = Helpers.Accounts.regular_user()
  #   %{user: user}
  # end

  defp create_regular_user_with_session(_) do
    {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    %{user: user, session: session}
  end

  defp assert_and_receive_email(user, subject) do
    # assert_email_sent(to: {user.first_name, user.email})

    receive do
      {:email, email} ->
        assert email.subject == subject
        assert email.to == [{user.first_name, user.email}]
        email
    after
      1_000 -> flunk("Email not received")
    end
  end
end
