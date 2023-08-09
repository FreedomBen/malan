defmodule Malan.AccountsTest do
  use Malan.DataCase, async: true

  alias Malan.Accounts
  alias Malan.Accounts.TermsOfService, as: ToS
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Utils
  alias Malan.Test.Utils, as: TestUtils
  alias Malan.Test.Helpers

  @user1_attrs %{
    "email" => "user1@email.com",
    "username" => "someusername1",
    "first_name" => "First Name1",
    "last_name" => "Last Name1",
    "nick_name" => "user nick1"
  }
  @user2_attrs %{
    "email" => "user2@email.com",
    "username" => "someusername2",
    "first_name" => "First Name2",
    "last_name" => "Last Name2",
    "nick_name" => "user nick2"
  }
  @update_attrs %{
    "password" => "some updated password",
    "preferences" => %{"theme" => "dark", "display_name_pref" => "custom"},
    "roles" => [],
    "sex" => "other",
    "gender" => "male"
  }
  @invalid_attrs %{
    "email" => nil,
    "email_verified" => nil,
    "password" => nil,
    "preferences" => nil,
    "roles" => nil,
    "username" => nil
  }

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(@user1_attrs)
      |> Accounts.register_user()

    user
  end

  describe "users" do
    alias Malan.Accounts.User
    alias Malan.Accounts.PhoneNumber

    defp strip_user(user), do: %{user | password: nil}

    defp norm_attrs(user) do
      cond do
        is_nil(user.custom_attrs) -> %{user | custom_attrs: %{}}
        true -> user
      end
    end

    def users_eq(u1, u2) do
      u1 |> norm_attrs() |> strip_user() == u2 |> norm_attrs() |> strip_user()
    end

    def assert_list_users_eq(l1, l2) do
      assert Enum.count(l1) == Enum.count(l2)

      # Check for equality ignoring order
      TestUtils.lists_equal_ignore_order(l1, l2)

      # Check for exact equality (including order)
      # l1
      # |> Enum.with_index()
      # |> Enum.each(fn {u, i} -> assert users_eq(u, Enum.at(l2, i)) end)
    end

    test "list_users/2 returns all users" do
      user = %{user_fixture() | password: nil, custom_attrs: %{}}
      # password should be nil coming from database since that's a virtual field
      users = Accounts.list_users(0, 10)
      assert is_list(users)
      assert Enum.member?(1..3, length(users))
      # assert(length(users) == 1 || length(users) == 3) # flakey based on seeds.exs adding 2
      assert Enum.any?(users, fn u -> user == u end)
    end

    test "list_users/2 paginates correctly" do
      {:ok, u1} = Helpers.Accounts.regular_user()
      {:ok, u2} = Helpers.Accounts.regular_user()
      {:ok, u3} = Helpers.Accounts.regular_user()

      [_ | lu] = Accounts.list_users(0, 10)
      assert lu |> Enum.count() == 3
      assert_list_users_eq(lu, [u1, u2, u3])

      assert Accounts.list_users(1, 1) |> Enum.count() == 1
      assert Accounts.list_users(2, 1) |> Enum.count() == 1
      assert Accounts.list_users(3, 1) |> Enum.count() == 1

      [
        Accounts.list_users(1, 1) |> Enum.at(0),
        Accounts.list_users(2, 1) |> Enum.at(0),
        Accounts.list_users(3, 1) |> Enum.at(0)
      ]
      |> TestUtils.lists_equal_ignore_order([u1, u2, u3])

      # Flaky code
      # assert users_eq(u1, Accounts.list_users(1, 1) |> Enum.at(0))
      # assert users_eq(u2, Accounts.list_users(2, 1) |> Enum.at(0))
      # assert users_eq(u3, Accounts.list_users(3, 1) |> Enum.at(0))
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()

      assert Accounts.get_user!(user.id) == %{
               user
               | password: nil,
                 tos_accept_events: [],
                 custom_attrs: %{}
             }
    end

    test "register_user/1 with valid data creates a user, email unverified and ToS not accepted" do
      assert {:ok, %User{} = user} = Accounts.register_user(@user1_attrs)
      assert user.email == "user1@email.com"
      assert user.email_verified == nil
      # password assigned randomly
      assert user.password =~ ~r/[A-Za-z0-9]{10}/
      # everybody gets "user" role by default
      assert user.roles == ["user"]
      assert user.tos_accept_events == []
      assert user.username == "someusername1"
      assert us = Accounts.get_user!(user.id)
      assert us.email == user.email
      # important check since password is hashed
      assert us.password == nil
      assert us.preferences == user.preferences
      assert us.roles == user.roles
      assert us.tos_accept_events == []
      assert us.custom_attrs == %{}
      assert us.username == user.username
    end

    test "register_user/1 can have password specified" do
      user1 = Map.put(@user1_attrs, "password", "examplepassword")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.password == "examplepassword"

      {:ok, user_id} =
        Accounts.authenticate_by_username_pass(user.username, user.password, "192.168.2.200")

      assert user_id == user.id
    end

    test "register_user/1 can have sex specified" do
      user1 = Map.put(@user1_attrs, "sex", "female")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.sex == "female"
      assert user.sex_enum == Malan.Accounts.User.Sex.to_i(user.sex)
      assert user.sex_enum == 1

      user2 = Map.put(@user2_attrs, "sex", "incorrect")
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(user2)

      user2 = Map.put(@user2_attrs, "sex", "male")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.sex == "male"
      assert user.sex_enum == Malan.Accounts.User.Sex.to_i(user.sex)
      assert user.sex_enum == 0
    end

    test "register_user/1 can have ethnicity specified" do
      user1 = Map.put(@user1_attrs, "ethnicity", "Hispanic or Latinx")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.ethnicity == "Hispanic or Latinx"
      assert user.ethnicity_enum == Malan.Accounts.User.Ethnicity.to_i(user.ethnicity)
      assert user.ethnicity_enum == 0

      user2 = Map.put(@user2_attrs, "ethnicity", "incorrect")
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(user2)

      user2 = Map.put(@user2_attrs, "ethnicity", "not hispanic or latinx")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.ethnicity == "not hispanic or latinx"
      assert user.ethnicity_enum == Malan.Accounts.User.Ethnicity.to_i(user.ethnicity)
      assert user.ethnicity_enum == 1
    end

    test "register_user/1 can have gender specified" do
      user1 = Map.put(@user1_attrs, "gender", "female")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.gender == "female"
      assert user.gender_enum == Malan.Accounts.User.Gender.to_i(user.gender)
      assert user.gender_enum == 51
      user2 = Map.put(@user2_attrs, "gender", "male")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.gender == "male"
      assert user.gender_enum == Malan.Accounts.User.Gender.to_i(user.gender)
      assert user.gender_enum == 50
    end

    test "register_user/1 rejects invalid gender" do
      user1 = Map.put(@user1_attrs, "gender", "fake")
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.register_user(user1)
      assert changeset.valid? == false

      assert errors_on(changeset).gender
             |> Enum.any?(fn x -> x =~ ~r/gender.is.invalid/ end)
    end

    test "admin can trigger a password reset with random value" do
      assert {:ok, ru} = Helpers.Accounts.regular_user()

      assert {:ok, user_id} =
               Accounts.authenticate_by_username_pass(ru.username, ru.password, "192.168.2.200")

      assert {:ok, user} = Accounts.admin_update_user(ru, %{password_reset: true})
      assert user.password =~ ~r/[A-Za-z0-9]{10}/

      assert {:ok, ^user_id} =
               Accounts.authenticate_by_username_pass(ru.username, ru.password, "192.168.2.200")
    end

    test "register_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.password == "some updated password"

      assert %{
               theme: "dark",
               id: _,
               display_name_pref: "custom",
               display_middle_initial_only: true
             } = user.preferences

      %{
        preferences: %{
          theme: "dark",
          display_name_pref: "custom",
          display_middle_initial_only: true
        }
      } = retuser = Accounts.get_user!(user.id)

      assert %{
               user
               | password: nil,
                 sex: nil,
                 sex_enum: 2,
                 gender: nil,
                 gender_enum: 50,
                 custom_attrs: %{},
                 preferences: %{}
             } == %{retuser | preferences: %{}}

      assert user.sex == "other"
    end

    test "update_user_password/2 with valid data updates the user's password" do
      %User{id: user_id} = user_fixture()

      assert {:ok, %User{} = user} =
               Accounts.update_user_password(user_id, "some updated password")

      assert user.password == "some updated password"
      assert %{user | password: nil} == Accounts.get_user!(user_id)
    end

    test "update_user/2 disallows setting mutable fields" do
      # attempt to change and then do a get from the db to
      # verify no changes
      uf = user_fixture()

      assert {:ok, %User{} = user} =
               Accounts.update_user(uf, %{
                 "email" => "shineshine@hushhush.com",
                 "username" => "TooShyShy"
               })

      assert user.email == "user1@email.com"
      assert user.username == "someusername1"

      assert %{uf | password: nil, tos_accept_events: [], custom_attrs: %{}} ==
               Accounts.get_user!(user.id)
    end

    test "update_user/2 disallows settings ToS or Email verify" do
      uf = user_fixture()
      %{email: "some@email.com", username: "someusername"}

      assert {:ok, %User{} = user} =
               Accounts.update_user(uf, %{
                 "email_verified" => DateTime.from_naive!(~N[2011-05-18T15:01:01Z], "Etc/UTC"),
                 "tos_accept_events" => DateTime.from_naive!(~N[2011-05-18T15:01:01Z], "Etc/UTC")
               })

      assert user.email_verified == nil
      assert user.tos_accept_events == []

      assert %{uf | password: nil, tos_accept_events: [], custom_attrs: %{}} ==
               Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, @invalid_attrs)
      assert changeset.valid? == false

      assert errors_on(changeset).password
             |> Enum.any?(fn x -> x =~ ~r/can.t.be.blank/ end)

      assert %{user | password: nil, tos_accept_events: [], custom_attrs: %{}} ==
               Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid sex returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, %{"sex" => "Y"})
      assert changeset.valid? == false

      assert errors_on(changeset).sex
             |> Enum.any?(fn x -> x =~ ~r/sex.is.invalid/ end)

      assert %{user | gender: nil, password: nil, tos_accept_events: [], custom_attrs: %{}} ==
               Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid gender returns error changeset" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.update_user(user, %{"gender" => "Y"})

      assert changeset.valid? == false

      assert errors_on(changeset).gender
             |> Enum.any?(fn x -> x =~ ~r/gender.is.invalid/ end)

      assert %{user | gender: nil, password: nil, tos_accept_events: [], custom_attrs: %{}} ==
               Accounts.get_user!(user.id)
    end

    # test "update_user/2 can be used to accept the ToS" do
    #   user1 = user_fixture()
    #   assert user1.tos_accept_events == []
    #   assert {:ok, %User{} = user2} = Accounts.update_user(user1, %{accept_tos: true})
    #   assert user2.password =~ ~r/[A-Za-z0-9]{10}/
    #   assert TestUtils.DateTime.within_last?(user2.tos_accept_events, 5, :seconds)
    #   assert %{ user2 | password: nil, accept_tos: nil } == Accounts.get_user!(user2.id)
    # end

    # test "update_user/2 doesn't accept ToS when set to false" do
    #   user = user_fixture()
    #   assert {:ok, %User{} = user} = Accounts.update_user(
    #     user, %{accept_tos: false, preferences: %{theme: "undark"}}
    #   )
    #   assert user.tos_accept_events == []
    #   assert user.preferences == %{theme: "undark"}
    #   assert %{
    #     user | password: nil, accept_tos: nil, preferences: %{"theme" => "undark"}, tos_accept_events: []
    #   } == Accounts.get_user!(user.id)
    # end

    test "#user_is_admin?/1 with user_id returns false when not an admin" do
      user = user_fixture()
      assert {:ok, false} = Accounts.user_is_admin?(user.id)
    end

    test "user_accept_tos/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_accept_tos(orig.id)

      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version} =
               List.first(user.tos_accept_events)

      assert tos_version == ToS.current_version()
      assert Utils.is_uuid?(id)
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert user.latest_tos_accept_ver == ToS.current_version()
    end

    test "user_reject_tos/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_reject_tos(orig.id)

      assert %{accept: false, id: id, timestamp: timestamp, tos_version: tos_version} =
               List.first(user.tos_accept_events)

      assert tos_version == ToS.current_version()
      assert Utils.is_uuid?(id)
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert user.latest_tos_accept_ver == nil
    end

    test "user_accept_tos/1 and user_reject_tos/1 prepends to the array" do
      orig = user_fixture()

      assert {:ok, u1} = Accounts.user_accept_tos(orig.id)

      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version} =
               List.first(u1.tos_accept_events)

      assert Utils.is_uuid?(id)
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)

      assert {:ok, u2} = Accounts.user_accept_tos(orig.id)
      assert length(u2.tos_accept_events) == 2

      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version} =
               Enum.at(u2.tos_accept_events, 0)

      assert Utils.is_uuid?(id)
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u2.latest_tos_accept_ver == ToS.current_version()

      assert {:ok, u3} = Accounts.user_reject_tos(orig.id)
      assert length(u2.tos_accept_events) == 2

      assert %{accept: false, id: id, timestamp: timestamp, tos_version: tos_version} =
               Enum.at(u3.tos_accept_events, 0)

      assert Utils.is_uuid?(id)
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u3.latest_tos_accept_ver == nil
    end

    test "user_accept_privacy_policy/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_accept_privacy_policy(orig.id)

      assert %{accept: true, id: id, timestamp: timestamp, privacy_policy_version: ppv} =
               List.first(user.privacy_policy_accept_events)

      assert Utils.is_uuid?(id)
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert ppv == PrivacyPolicy.current_version()
      assert user.latest_pp_accept_ver == PrivacyPolicy.current_version()
    end

    test "user_reject_privacy_policy/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_reject_privacy_policy(orig.id)

      assert %{accept: false, id: id, timestamp: timestamp, privacy_policy_version: ppv} =
               List.first(user.privacy_policy_accept_events)

      assert Utils.is_uuid?(id)
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert ppv == PrivacyPolicy.current_version()
      assert user.latest_pp_accept_ver == nil
    end

    test "user_accept_privacy_policy/1 and user_reject_privacy_policy/1 prepends to the array" do
      orig = user_fixture()

      assert {:ok, u1} = Accounts.user_accept_privacy_policy(orig.id)

      assert %{
               accept: true,
               id: id,
               timestamp: timestamp,
               privacy_policy_version: privacy_policy_version
             } = List.first(u1.privacy_policy_accept_events)

      assert Utils.is_uuid?(id)
      assert privacy_policy_version == PrivacyPolicy.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)

      assert {:ok, u2} = Accounts.user_accept_privacy_policy(orig.id)
      assert length(u2.privacy_policy_accept_events) == 2

      assert %{
               accept: true,
               id: id,
               timestamp: timestamp,
               privacy_policy_version: privacy_policy_version
             } = Enum.at(u2.privacy_policy_accept_events, 0)

      assert Utils.is_uuid?(id)
      assert privacy_policy_version == PrivacyPolicy.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u2.latest_pp_accept_ver == PrivacyPolicy.current_version()

      assert {:ok, u3} = Accounts.user_reject_privacy_policy(orig.id)
      assert length(u2.privacy_policy_accept_events) == 2

      assert %{
               accept: false,
               id: id,
               timestamp: timestamp,
               privacy_policy_version: privacy_policy_version
             } = Enum.at(u3.privacy_policy_accept_events, 0)

      assert Utils.is_uuid?(id)
      assert privacy_policy_version == PrivacyPolicy.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u3.latest_pp_accept_ver == nil
    end

    @tag :skip
    test "user_verify_email/2 works only for system user" do
      assert false
    end

    test "update_user/2 doesn't allow a user to change their roles" do
      user = user_fixture()
      assert user.roles == ["user"]

      assert {:ok, %Accounts.User{} = updated_user} =
               Accounts.update_user(user, %{"roles" => ["admin", "moderator"]})

      assert updated_user.roles == ["user"]
    end

    test "get_user/1 and get_user!/1 work and delete_user/1 deletes the user" do
      user = user_fixture()
      assert %{user | password: nil, custom_attrs: %{}} == Accounts.get_user(user.id)
      assert %{user | password: nil, custom_attrs: %{}} == Accounts.get_user!(user.id)
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
      assert is_nil(Accounts.get_user(user.id))
    end

    test "delete_user/1 changes username and email, sets deleted_at" do
      get_u = fn id -> Repo.one(from(u in User, where: u.id == ^id)) end
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
      retval = get_u.(user.id)
      assert String.ends_with?(retval.email, "|#{user.email}")
      assert String.ends_with?(retval.username, "|#{user.username}")
    end

    test "delete_user/1 can be called multiple times" do
      # We need to do our own query because the Accounts ones omit deleted
      get_u = fn id -> Repo.one(from(u in User, where: u.id == ^id)) end

      u1 = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(u1)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(u1.id) end
      retval = get_u.(u1.id)
      assert String.ends_with?(retval.email, "|#{u1.email}")
      assert String.ends_with?(retval.username, "|#{u1.username}")

      # Recreate the user and delete it again
      u2 = user_fixture(%{"email" => u1.email, "username" => u1.username})
      assert {:ok, %User{}} = Accounts.delete_user(u2)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(u2.id) end
      retval = get_u.(u2.id)
      assert String.ends_with?(retval.email, "|#{u2.email}")
      assert String.ends_with?(retval.username, "|#{u2.username}")
    end

    test "delete_user/1 cannot be called on an already deleted user" do
      get_u = fn id -> Repo.one(from(u in User, where: u.id == ^id)) end
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
      retval = get_u.(user.id)
      assert String.ends_with?(retval.email, "|#{user.email}")
      assert String.ends_with?(retval.username, "|#{user.username}")
    end

    test "Usernames must be unique on creation" do
      user1_attrs = %{@user1_attrs | "username" => "someusername"}
      user2_attrs = %{@user2_attrs | "username" => "someusername"}
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.username == "someusername"
      assert user1.email == "user1@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).username
             |> Enum.any?(fn x -> x =~ ~r/has already been taken/ end)
    end

    test "Usernames must be unique and case insensitive" do
      user1_attrs = %{@user1_attrs | "username" => "someusername"}
      user2_attrs = %{@user2_attrs | "username" => "SoMeUsErNAmE"}
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.username == "someusername"
      assert user1.email == "user1@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).username
             |> Enum.any?(fn x -> x =~ ~r/has already been taken/ end)
    end

    test "Email must be unique on creation" do
      user1_attrs = %{@user1_attrs | "email" => "some@email.com"}
      user2_attrs = %{@user2_attrs | "email" => "some@email.com"}
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.email == "some@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).email
             |> Enum.any?(fn x -> x =~ ~r/has already been taken/ end)
    end

    test "Email must be unique on creation and case insensitive" do
      user1_attrs = %{@user1_attrs | "email" => "some@email.com"}
      user2_attrs = %{@user2_attrs | "email" => "SOME@email.com"}
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.email == "some@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).email
             |> Enum.any?(fn x -> x =~ ~r/has already been taken/ end)
    end

    test "Can set arbitrary JSON on a user" do
      custom_attrs = %{"some_val" => "some_val", "second" => %{"third" => "third"}}
      uf = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(uf, %{"custom_attrs" => custom_attrs})
      assert %{"some_val" => "some_val", "second" => %{"third" => "third"}} = user.custom_attrs
      assert %{user | password: nil} == Accounts.get_user!(user.id)
    end

    test "update_user_password/2 updates the user's password" do
      new_password = "sodabubbles"
      %User{id: user_id} = uf = user_fixture()
      {:ok, user} = Accounts.update_user_password(uf.id, new_password)
      assert user.password != uf.password
      assert user.password == new_password
      assert %{user | password: nil} == Accounts.get_user!(user_id)
    end

    test "generate_password_reset/1 adds a reset token to the database and an expiration" do
      uf = user_fixture()
      user = Accounts.get_user(uf.id)
      assert is_nil(uf.password_reset_token)
      assert is_nil(uf.password_reset_token_hash)
      assert is_nil(uf.password_reset_token_expires_at)
      {:ok, updated} = Accounts.generate_password_reset(user)

      assert %{
               updated
               | password_reset_token: nil,
                 password_reset_token_hash: nil,
                 password_reset_token_expires_at: nil
             } == user

      assert updated.password_reset_token
      assert updated.password_reset_token_hash
      assert updated.password_reset_token_expires_at
      uuser = Accounts.get_user(updated.id)
      # should be blank now
      assert is_nil(uuser.password_reset_token)
      assert uuser.password_reset_token_hash
      assert uuser.password_reset_token_expires_at
    end

    test "validate_password_reset_token/2 logic test: returns properly with no token" do
      # this won't have a password reset token yet
      uf = user_fixture()

      assert {:error, :missing_password_reset_token} =
               Accounts.validate_password_reset_token(uf, "")

      assert {:error, :missing_password_reset_token} =
               Accounts.validate_password_reset_token(uf, nil)

      assert {:error, :missing_password_reset_token} =
               Accounts.validate_password_reset_token(uf, "abcde")
    end

    test "validate_password_reset_token/2 logic test: returns properly incorrect token" do
      uf =
        user_fixture()
        |> Map.merge(%{
          password_reset_token: "ohai",
          password_reset_token_hash: "hellow",
          password_reset_token_expires_at: Utils.DateTime.adjust_cur_time(1, :minutes)
        })

      assert {:error, :invalid_password_reset_token} =
               Accounts.validate_password_reset_token(uf, "helloworld")

      assert {:error, :invalid_password_reset_token} =
               Accounts.validate_password_reset_token(uf, "42")
    end

    test "validate_password_reset_token/2 logic test: returns properly with valid token" do
      uf = user_fixture()
      {:ok, user} = Accounts.generate_password_reset(uf)
      assert {:ok} = Accounts.validate_password_reset_token(user, user.password_reset_token)
    end

    test "validate_password_reset_token/2 logic test: returns expired when expired" do
      uf =
        user_fixture()
        |> Map.merge(%{
          password_reset_token: "ohai",
          password_reset_token_hash: "hellow",
          password_reset_token_expires_at: Utils.DateTime.adjust_cur_time(-1, :minutes)
        })

      {:ok, user} = Accounts.generate_password_reset(uf)
      assert {:ok} = Accounts.validate_password_reset_token(user, user.password_reset_token)
    end

    test "clear_password_reset_token/1 clears old password reset token" do
      uf = user_fixture()
      {:ok, user} = Accounts.generate_password_reset(uf)
      assert {:ok} = Accounts.validate_password_reset_token(user, user.password_reset_token)
      assert {:ok} = Accounts.validate_password_reset_token(user, user.password_reset_token)
      # We know token is valid, now lets clear it
      assert {:ok, cleared_user} = Accounts.clear_password_reset_token(user)
      assert is_nil(cleared_user.password_reset_token)
      assert is_nil(cleared_user.password_reset_token_hash)

      assert {:error, :missing_password_reset_token} =
               Accounts.validate_password_reset_token(cleared_user, user.password_reset_token)

      assert {:error, :missing_password_reset_token} =
               Accounts.validate_password_reset_token(
                 cleared_user,
                 cleared_user.password_reset_token
               )
    end

    test "get_user_by/1" do
      uf = user_fixture()

      u1 = Accounts.get_user_by(username: uf.username)
      assert %{uf | custom_attrs: %{}, password: nil} == u1

      u2 = Accounts.get_user_by(email: uf.email)
      assert %{uf | custom_attrs: %{}, password: nil} == u2

      u3 = Accounts.get_user_by(last_name: uf.last_name)
      assert %{uf | custom_attrs: %{}, password: nil} == u3

      u4 = Accounts.get_user_by(first_name: uf.first_name)
      assert %{uf | custom_attrs: %{}, password: nil} == u4

      u5 = Accounts.get_user_by(first_name: "Not a real first name")
      assert is_nil(u5)

      assert u1 == u2
      assert u1 == u3
      assert u1 == u4
    end

    test "get_user_by/1 does not include deleted users" do
      uf = user_fixture()

      assert {:ok, %User{}} = Accounts.delete_user(uf)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(uf.id) end
      assert is_nil(Accounts.get_user(uf.id))

      assert Accounts.get_user_by(username: uf.username) |> is_nil()
      assert Accounts.get_user_by(email: uf.email) |> is_nil()
      assert Accounts.get_user_by(last_name: uf.last_name) |> is_nil()
      assert Accounts.get_user_by(first_name: uf.first_name) |> is_nil()
      assert Accounts.get_user_by(first_name: "Not a real first name") |> is_nil()
    end

    test "get_user_by!/1" do
      uf = user_fixture()

      u1 = Accounts.get_user_by!(username: uf.username)
      assert %{uf | custom_attrs: %{}, password: nil} == u1

      u2 = Accounts.get_user_by!(email: uf.email)
      assert %{uf | custom_attrs: %{}, password: nil} == u2

      u3 = Accounts.get_user_by!(last_name: uf.last_name)
      assert %{uf | custom_attrs: %{}, password: nil} == u3

      u4 = Accounts.get_user_by!(first_name: uf.first_name)
      assert %{uf | custom_attrs: %{}, password: nil} == u4

      assert u1 == u2
      assert u1 == u3
      assert u1 == u4

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user_by!(first_name: "Not a real first name")
      end
    end

    test "get_user_by!/1 does not include deleted users" do
      uf = user_fixture()

      assert {:ok, %User{}} = Accounts.delete_user(uf)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(uf.id) end
      assert is_nil(Accounts.get_user(uf.id))

      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by!(username: uf.username) end
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by!(email: uf.email) end
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by!(last_name: uf.last_name) end
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_by!(first_name: uf.first_name) end

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user_by!(first_name: "Not a real first name")
      end
    end

    test "get_user_by_password_reset_token/1" do
      # This is tested by the user controller test
    end

    test "get_user_by_email/1" do
      uf = user_fixture()
      u1 = Accounts.get_user_by_email(uf.email)
      assert %{uf | custom_attrs: %{}, password: nil} == u1
    end

    test "get_user_by_id_or_username/1" do
      uf = user_fixture()
      u1 = Accounts.get_user_by_id_or_username!(uf.username)
      assert %{uf | custom_attrs: %{}, password: nil} == u1
      u2 = Accounts.get_user_by_id_or_username!(uf.id)
      assert %{uf | custom_attrs: %{}, password: nil} == u2
      assert u1 == u2
    end

    test "when creating users the username and email are lowercased" do
      uf = user_fixture(%{"username" => "CaPitAlUsername", "email" => "CaPitALaddr@example.COM"})
      assert uf.email == "capitaladdr@example.com"
      assert uf.username == "capitalusername"

      assert %User{
               email: "capitaladdr@example.com",
               username: "capitalusername"
             } = Accounts.get_user(uf.id)
    end

    test "getting a user with capitals by username returns the correct" do
      orig_email = "CaPitALaddr@example.COM"
      orig_username = "CaPitAlUsername"
      %User{id: user_id} = user_fixture(%{"username" => orig_username, "email" => orig_email})

      assert %User{
               id: ^user_id,
               email: "capitaladdr@example.com",
               username: "capitalusername"
             } = Accounts.get_user_by_id_or_username(orig_username)
    end

    test "getting a user with capitals by email returns the correct" do
      orig_email = "CaPitALaddr@example.COM"
      orig_username = "CaPitAlUsername"
      %User{id: user_id} = user_fixture(%{"username" => orig_username, "email" => orig_email})

      assert %User{
               id: ^user_id,
               email: "capitaladdr@example.com",
               username: "capitalusername"
             } = Accounts.get_user_by!(email: orig_email)
    end

    test "get_user_full/1 works" do
      number = "123456789"
      phone_numbers = [%{number: number}]
      %User{id: user_id, username: username} = user_fixture(%{"phone_numbers" => phone_numbers})

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full(user_id)
    end

    test "get_user_full/1 returns nil when not found" do
      assert is_nil(Accounts.get_user_full(Ecto.UUID.generate()))
    end

    test "get_user_full!/1 works" do
      number = "123456789"
      phone_numbers = [%{number: number}]
      %User{id: user_id, username: username} = user_fixture(%{"phone_numbers" => phone_numbers})

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full!(user_id)
    end

    test "get_user_full!/1 raises when not found" do
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user_full!(Ecto.UUID.generate()) end
    end

    test "get_user_full_by_id_or_username/1 works" do
      number = "123456789"
      phone_numbers = [%{number: number}]
      %User{id: user_id, username: username} = user_fixture(%{"phone_numbers" => phone_numbers})

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full_by_id_or_username(user_id)

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full_by_id_or_username(username)
    end

    test "get_user_full_by_id_or_username/1 returns nil when not found" do
      assert is_nil(Accounts.get_user_full_by_id_or_username(Ecto.UUID.generate()))

      assert is_nil(
               Accounts.get_user_full_by_id_or_username("notavalididorusernameoremailaddress")
             )
    end

    test "get_user_full_by_id_or_username!/1 works" do
      number = "123456789"
      phone_numbers = [%{number: number}]
      %User{id: user_id, username: username} = user_fixture(%{"phone_numbers" => phone_numbers})

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full_by_id_or_username!(user_id)

      assert %User{
               id: ^user_id,
               username: ^username,
               phone_numbers: [%PhoneNumber{number: ^number}]
             } = Accounts.get_user_full_by_id_or_username!(username)
    end

    test "get_user_full_by_id_or_username!/1 raises when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user_full_by_id_or_username!(Ecto.UUID.generate())
      end

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user_full_by_id_or_username!("notavalididorusernameoremailaddress")
      end
    end

    test "lock/2" do
      u1 = user_fixture()
      assert is_nil(u1.locked_at)
      assert is_nil(u1.locked_by)

      {:ok, u2} = Accounts.lock_user(u1, u1.id)
      assert TestUtils.DateTime.within_last?(u2.locked_at, 2, :seconds)
      assert u1.id == u2.locked_by

      u3 = Accounts.get_user(u1.id)
      assert TestUtils.DateTime.within_last?(u3.locked_at, 2, :seconds)
      assert u1.id == u3.locked_by
    end

    test "unlock/1" do
      u1 = user_fixture()
      {:ok, u1} = Accounts.lock_user(u1, u1.id)
      assert TestUtils.DateTime.within_last?(u1.locked_at, 2, :seconds)
      assert u1.id == u1.locked_by

      u1 = Accounts.get_user(u1.id)
      assert TestUtils.DateTime.within_last?(u1.locked_at, 2, :seconds)
      assert u1.id == u1.locked_by

      {:ok, u2} = Accounts.unlock_user(u1)
      assert is_nil(u2.locked_by)
      assert is_nil(u2.locked_at)
    end
  end

  describe "sessions" do
    alias Malan.Accounts.Session

    def session_fixture(user_attrs \\ %{}, session_attrs \\ %{}) do
      user = user_fixture(user_attrs)

      {:ok, session} =
        Accounts.create_session(
          user.username,
          user.password,
          "192.168.2.200",
          Map.merge(
            %{"ip_address" => "192.168.2.200"},
            session_attrs
          )
        )

      session
    end

    def session_valid_fixture(args \\ %{}) do
      %{
        user_id: "user_id",
        username: "username",
        session_id: "session_id",
        expires_at: Utils.DateTime.adjust_cur_time(7, :days),
        revoked_at: nil,
        ip_address: "127.0.0.1",
        valid_only_for_ip: false,
        roles: ["user"],
        latest_tos_accept_ver: "1",
        latest_pp_accept_ver: "2"
      }
      |> Map.merge(args)
    end

    def nillify_api_token(sessions) when is_list(sessions) do
      sessions
      |> Enum.map(fn s -> nillify_api_token(s) end)
    end

    def nillify_api_token(session) do
      %{session | api_token: nil}
    end

    test "list_sessions/2 returns all sessions" do
      session = %{session_fixture() | api_token: nil, extendable_until_seconds: nil}
      assert Accounts.list_sessions(0, 10) == [session]
      assert Accounts.list_sessions(1, 10) == []
    end

    test "list_sessions/2 returns all sessions paginated" do
      {:ok, u1, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, s2} = Helpers.Accounts.create_session(u1)
      {:ok, s3} = Helpers.Accounts.create_session(u1)
      {:ok, s4} = Helpers.Accounts.create_session(u1)
      {:ok, s5} = Helpers.Accounts.create_session(u1)
      {:ok, s6} = Helpers.Accounts.create_session(u1)

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(0, 10),
               nillify_api_token([s1, s2, s3, s4, s5, s6])
             )

      assert TestUtils.lists_equal_ignore_order(Accounts.list_sessions(1, 10), [])

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(0, 2),
               nillify_api_token([s1, s2])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(1, 2),
               nillify_api_token([s3, s4])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(2, 2),
               nillify_api_token([s5, s6])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(3, 2),
               nillify_api_token([])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(0, 4),
               nillify_api_token([s1, s2, s3, s4])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(1, 4),
               nillify_api_token([s5, s6])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(2, 4),
               nillify_api_token([])
             )
    end

    test "get_session!/1 returns the session with given id" do
      session = session_fixture()

      assert Accounts.get_session!(session.id) == %{
               session
               | api_token: nil,
                 extendable_until_seconds: nil
             }
    end

    test "create_session/3 with valid data creates a session" do
      user = user_fixture()

      assert {:ok, %Session{} = session} =
               Accounts.create_session(user.username, user.password, "192.168.2.200", %{
                 "ip_address" => "192.168.2.200"
               })

      # API token should be included after creation, but not after that
      assert session.api_token =~ ~r/[A-Za-z0-9]{10}/
      assert TestUtils.DateTime.within_last?(session.authenticated_at, 5, :seconds) == true

      assert Enum.member?(
               0..5,
               DateTime.diff(DateTime.utc_now(), session.authenticated_at, :second)
             )

      assert Enum.member?(
               0..5,
               DateTime.diff(
                 Utils.DateTime.adjust_cur_time(1, :weeks),
                 session.expires_at,
                 :second
               )
             )

      assert session.ip_address == "192.168.2.200"
      assert session.revoked_at == nil
    end

    test "create_session/3 with expires_never at true expires over 200 years from now" do
      user = user_fixture()

      assert {:ok, %Session{} = session} =
               Accounts.create_session(
                 user.username,
                 user.password,
                 "192.168.2.200",
                 %{
                   "never_expires" => true,
                   "ip_address" => "192.168.2.200"
                 }
               )

      assert DateTime.diff(session.expires_at, DateTime.utc_now()) > 5_000_000_000
      assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(session.api_token, nil)
    end

    test "create_session/3 with expires_in_seconds expires at specified time" do
      user = user_fixture()

      assert {:ok, %Session{} = session} =
               Accounts.create_session(
                 user.username,
                 user.password,
                 "192.168.2.200",
                 %{
                   "expires_in_seconds" => -120,
                   "ip_address" => "192.168.2.200"
                 }
               )

      assert !TestUtils.DateTime.within_last?(session.expires_at, 119, :seconds)
      assert TestUtils.DateTime.within_last?(session.expires_at, 125, :seconds)
      assert {:error, :expired} = Accounts.validate_session(session.api_token, nil)
    end

    test "create_session/1 never_expire set to 'false' doesn't affect stuff" do
      user = user_fixture()

      assert {:ok, %Session{} = session} =
               Accounts.create_session(
                 user.username,
                 user.password,
                 "192.168.2.200",
                 %{
                   "never_expires" => false,
                   "expires_in_seconds" => -120,
                   "ip_address" => "192.168.2.200"
                 }
               )

      assert !TestUtils.DateTime.within_last?(session.expires_at, 119, :seconds)
      assert TestUtils.DateTime.within_last?(session.expires_at, 125, :seconds)
      assert {:error, :expired} = Accounts.validate_session(session.api_token, nil)
    end

    test "create_session/1 doesn't allow specifying user ID" do
      user1 = user_fixture(%{"username" => "username1"})
      user2 = user_fixture(%{"username" => "username2", "email" => "username2@example.com"})

      assert {:ok, session} =
               Accounts.create_session(
                 user1.username,
                 user1.password,
                 "192.168.2.200",
                 %{
                   "user_id" => user2.id,
                   "ip_address" => "192.168.2.200"
                 }
               )

      assert user2.id != user1.id
      assert session.user_id == user1.id
    end

    test "get_user_id_pass_hash_by_username/1 returns {user_id, password_hash, locked_at} on success" do
      user = user_fixture()

      assert {user_id, password_hash, nil, []} =
               Accounts.get_user_id_pass_hash_by_username(user.username)

      assert user_id == user.id
      assert password_hash == user.password_hash
    end

    test "get_user_id_pass_hash_by_username/1 returns nil on username not found" do
      assert nil == Accounts.get_user_id_pass_hash_by_username("notarealusernameatall")
    end

    test "get_user_id_pass_hash_by_username/1 returns locked_at as datetime when user is locked" do
      user = user_fixture()

      assert {user_id, password_hash, nil, []} =
               Accounts.get_user_id_pass_hash_by_username(user.username)

      assert user_id == user.id

      {:ok, user} = Accounts.lock_user(user, nil)

      assert {^user_id, ^password_hash, locked_at, []} =
               Accounts.get_user_id_pass_hash_by_username(user.username)

      assert locked_at == user.locked_at
    end

    test "create_session/1 with incorrect pass returns {:error, :unauthorized}" do
      user = user_fixture()

      assert {:error, :unauthorized} =
               Accounts.create_session(user.username, "nottherightpassword", "192.168.2.200", %{
                 "ip_address" => "192.168.2.200"
               })
    end

    test "create_session/1 with non-existent user returns {:error, :not_a_user}" do
      assert {:error, :not_a_user} =
               Accounts.create_session(
                 "notarealusernameatall",
                 "nottherightpassword",
                 "192.168.2.200",
                 %{"ip_address" => "192.168.2.200"}
               )
    end

    test "delete_session/1 revokes the session" do
      session = session_fixture()
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      sesh = Accounts.get_session!(session.id)
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), sesh.revoked_at, :second))
    end

    test "validate_session/2 returns a user id, roles, and expires_at when the session is valid" do
      session = session_fixture(%{"username" => "randomusername1"})
      assert {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, roles, exp, tos,
              pp} = Accounts.validate_session(session.api_token, "1.1.1.1")

      assert user_id == session.user_id
      assert username == "randomusername1"
      assert session_id == session.id
      assert roles == ["user"]
      assert ip_address == session.ip_address
      assert valid_only_for_ip == session.valid_only_for_ip

      assert TestUtils.DateTime.first_after_second_within?(
               Utils.DateTime.adjust_cur_time(1, :weeks),
               exp,
               3,
               :seconds
             )

      assert is_nil(tos)
      assert is_nil(pp)
    end

    test "validate_session/2 return an error when the session is revoked" do
      session = session_fixture(%{"username" => "randomusername2"})
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      assert {:error, :revoked} = Accounts.validate_session(session.api_token, "1.1.1.1")
    end

    test "validate_session/2 return an error when the session is revoked even when token expires infinitely" do
      session = session_fixture(%{"username" => "randomusername2"}, %{"never_expires" => false})
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      assert {:error, :revoked} = Accounts.validate_session(session.api_token, "1.1.1.1")
    end

    test "validate_session/2 return an error when the session is expired" do
      session = session_fixture(%{"username" => "randomusername3"}, %{"expires_in_seconds" => -5})
      assert {:error, :expired} = Accounts.validate_session(session.api_token, "1.1.1.1")
    end

    test "validate_session/2 return an error when the session token does not exist" do
      assert {:error, :not_found} = Accounts.validate_session("notavalidtoken", "1.1.1.1")
    end

    test "validate_session/2 returns properly when remote IP matches" do
      session =
        session_fixture(%{"username" => "randomusername2"}, %{
          "ip_address" => "1.1.1.1",
          "valid_only_for_ip" => true
        })

      assert {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, _roles, exp,
              _tos, _pp} = Accounts.validate_session(session.api_token, "1.1.1.1")

      assert exp == session.expires_at
      assert user_id == session.user_id
      assert username == "randomusername2"
      assert session_id == session.id
      assert ip_address == session.ip_address
      assert valid_only_for_ip == session.valid_only_for_ip
    end

    test "validate_session/2 returns an error when remote IP doesn't match" do
      session =
        session_fixture(%{}, %{
          "username" => "randomusername2",
          "ip_address" => "1.1.1.1",
          "valid_only_for_ip" => true
        })

      assert {:error, :ip_addr} = Accounts.validate_session(session.api_token, "127.0.0.1")
    end

    test "update_user/2 can be used to update user preferences" do
      user = user_fixture()

      update_user_prefs = %{
        "preferences" => %{
          "invalid" => "invalid",
          "theme" => "dark",
          "display_name_pref" => "full_name",
          "display_middle_initial_only" => false
        }
      }

      assert {:ok, %Accounts.User{} = updated_user} =
               Accounts.update_user(user, update_user_prefs)

      assert %{id: _, theme: "dark", display_name_pref: "full_name"} = updated_user.preferences
      assert false == Map.has_key?(updated_user.preferences, :invalid)
    end

    test "update_user/2 invalid theme is rejected" do
      user = user_fixture()

      update_user_prefs = %{
        "preferences" => %{
          "theme" => "invalid"
        }
      }

      assert {:error, changeset} = Accounts.update_user(user, update_user_prefs)

      assert errors_on(changeset).preferences.theme
             |> Enum.any?(fn x -> x =~ ~r/valid.themes.are/i end)
    end

    test "update_user/2 invalid display_name_pref is rejected" do
      user = user_fixture()

      update_user_prefs = %{
        "preferences" => %{
          "display_name_pref" => "invalid"
        }
      }

      assert {:error, changeset} = Accounts.update_user(user, update_user_prefs)

      assert errors_on(changeset).preferences.display_name_pref
             |> Enum.any?(fn x -> x =~ ~r/valid.display_name_prefs.are/i end)
    end

    test "update_user/2 overwrites old preferences and check default display_name_pref" do
      user = user_fixture()

      update_user_prefs = %{
        "preferences" => %{
          "theme" => "dark"
        }
      }

      assert {:ok, %Accounts.User{} = updated_user} =
               Accounts.update_user(user, update_user_prefs)

      assert %{
               id: _,
               theme: "dark",
               display_name_pref: "nick_name",
               display_middle_initial_only: true
             } = updated_user.preferences

      assert false == Map.has_key?(updated_user.preferences, :invalid)

      second_user_prefs = %{
        "preferences" => %{
          "theme" => "dark",
          "display_name_pref" => "full_name",
          "display_middle_initial_only" => true
        }
      }

      assert {:ok, %Accounts.User{} = updated_user} =
               Accounts.update_user(user, second_user_prefs)

      assert %{id: _, theme: "dark", display_name_pref: "full_name"} = updated_user.preferences
    end

    test "revoke_active_sessions/1 revokes all session for the user except non-expiring" do
      {:ok, user} = Helpers.Accounts.regular_user()

      sessions =
        1..3
        |> Enum.map(fn _i ->
          {:ok, session} = Helpers.Accounts.create_session(user)
          session
        end)

      {:ok, forever_session} = Helpers.Accounts.create_session(user, %{"never_expires" => true})

      assert {:ok, _, _, _, _, _, _, exp, _, _} =
               Accounts.validate_session(forever_session.api_token, nil)

      assert DateTime.compare(
               Utils.DateTime.adjust_cur_time(36500, :days),
               exp
             ) == :lt

      Enum.each(sessions, fn s ->
        assert {:ok, user_id, _username, _, _, _, _, _, _, _} =
                 Accounts.validate_session(s.api_token, nil)

        assert user_id == user.id
      end)

      Accounts.revoke_active_sessions(user)

      Enum.each(sessions, fn s ->
        assert {:error, :revoked} = Accounts.validate_session(s.api_token, nil)
      end)
    end

    test "user_add_role/2 adds the role to the user" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:ok, false} = Accounts.user_is_admin?(user.id)
      Accounts.user_add_role("admin", user.id)
      assert {:ok, true} = Accounts.user_is_admin?(user.id)
    end

    test "session_valid?/2 with nil returns error not found" do
      assert {:error, :not_found} = Accounts.session_valid?(nil, nil)
    end

    test "session_valid?/2 with map revoked tokens always shows revoked" do
      assert {:error, :revoked} =
               Accounts.session_valid?(
                 session_valid_fixture(%{revoked_at: DateTime.utc_now()}),
                 nil
               )

      assert {:error, :revoked} =
               Accounts.session_valid?(
                 session_valid_fixture(%{
                   expires_at: Utils.DateTime.adjust_cur_time(-2, :hours),
                   revoked_at: DateTime.utc_now()
                 }),
                 nil
               )
    end

    test "session_valid?/2 returns expected structure when valid" do
      args =
        %{
          user_id: user_id,
          username: "fakeusername1",
          session_id: session_id,
          expires_at: expires_at,
          revoked_at: _revoked_at,
          ip_address: ip_address,
          valid_only_for_ip: valid_only_for_ip,
          roles: roles,
          latest_tos_accept_ver: latest_tos_accept_ver,
          latest_pp_accept_ver: latest_pp_accept_ver
        } = %{
          user_id: "123",
          username: "fakeusername1",
          session_id: "abc",
          expires_at: Utils.DateTime.adjust_cur_time(2, :days),
          revoked_at: nil,
          ip_address: "127.0.0.1",
          valid_only_for_ip: false,
          roles: ["user"],
          latest_tos_accept_ver: "12",
          latest_pp_accept_ver: "13"
        }

      assert {:ok, ^user_id, "fakeusername1", ^session_id, ^ip_address, ^valid_only_for_ip,
              ^roles, ^expires_at, ^latest_tos_accept_ver,
              ^latest_pp_accept_ver} = Accounts.session_valid?(args, nil)
    end

    test "session_valid?/2 with map expired but not revoked is expired" do
      assert {:error, :expired} =
               Accounts.session_valid?(
                 session_valid_fixture(%{
                   expires_at: Utils.DateTime.adjust_cur_time(-2, :hours),
                   revoked_at: nil
                 }),
                 nil
               )
    end

    test "session_valid?/2 with forever token is valid" do
      assert {:ok, _, _, _, _, _, _, _, _, _} =
               Accounts.session_valid?(
                 session_valid_fixture(%{
                   expires_at: Utils.DateTime.distant_future(),
                   revoked_at: nil
                 }),
                 nil
               )
    end

    test "session_valid?/2 validates for correct IP address" do
      assert {:ok, _, _, _, "1.1.1.1", true, _, _, _, _} =
               Accounts.session_valid?(
                 session_valid_fixture(%{
                   ip_address: "1.1.1.1",
                   valid_only_for_ip: true,
                   revoked_at: nil,
                   expires_at: Utils.DateTime.distant_future()
                 }),
                 "1.1.1.1"
               )
    end

    test "session_valid?/2 rejects for incorrect IP address" do
      assert {:error, :ip_addr} =
               Accounts.session_valid?(
                 session_valid_fixture(%{
                   ip_address: "1.1.1.1",
                   valid_only_for_ip: true,
                   revoked_at: nil,
                   expires_at: Utils.DateTime.distant_future()
                 }),
                 "127.0.0.1"
               )
    end

    test "session_expired?/1" do
      session = session_fixture()
      assert false == Accounts.session_expired?(session)
      assert false == Accounts.session_expired?(session.expires_at)

      session = Helpers.Accounts.set_expired(session)
      assert true == Accounts.session_expired?(session)
      assert true == Accounts.session_expired?(session.expires_at)
    end

    test "Creating a new session allows specifying max extension time" do
      # Pass the max extension time to Accounts.create_session
      session = session_fixture(%{}, %{"extendable_until_seconds" => 2 * 60 * 60})
      expected_new_max_extension_time = Utils.DateTime.adjust_cur_time(2, :hours)

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{extendable_until: extendable_until} =
        Accounts.get_session!(session.id)

      assert extendable_until == Utils.DateTime.truncate(expected_new_max_extension_time)
    end

    test "Creating a new session without specifying extension time uses default" do
      session = session_fixture()

      %Malan.Accounts.Session{max_extension_secs: max_extension_secs} =
        Accounts.get_session!(session.id)

      assert max_extension_secs == Malan.Config.Session.default_max_extension_secs()
    end

    test "Default max extension time works" do
      # Pass the max extension time to Accounts.create_session
      session = session_fixture()
      expected_new_max_extension_time = Utils.DateTime.adjust_cur_time(4, :weeks)

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{extendable_until: extendable_until} =
        Accounts.get_session!(session.id)

      assert TestUtils.DateTime.datetimes_within?(
               expected_new_max_extension_time,
               extendable_until,
               2,
               :seconds
             )
    end

    test "Setting max extension time (for a new session) beyond the global maximum gets you the global maximum" do
      # Pass the max extension time that exceeds our limit by 1 day (24 hours)
      too_long_max_extension_secs = Malan.Config.Session.max_max_extension_secs() + 60 * 60 * 24

      too_long_max_extension_time =
        Utils.DateTime.adjust_cur_time(too_long_max_extension_secs, :seconds)

      session =
        session_fixture(%{}, %{
          "extendable_until_seconds" => too_long_max_extension_secs,
          "max_extension_seconds" => too_long_max_extension_secs
        })

      expected_new_max_extension_time = Utils.DateTime.adjust_cur_time(13, :weeks)

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{extendable_until: extendable_until} =
        Accounts.get_session!(session.id)

      assert TestUtils.DateTime.datetimes_within?(
               expected_new_max_extension_time,
               extendable_until,
               2,
               :seconds
             )

      assert !TestUtils.DateTime.datetimes_within?(
               too_long_max_extension_time,
               extendable_until,
               2,
               :seconds
             )
    end

    test "A session can be properly extended" do
      # Initial session expires after 30 minutes
      session = session_fixture(%{}, %{"expires_in_seconds" => 1800})
      cur_exp_time = session.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               cur_exp_time,
               Utils.DateTime.adjust_cur_time(30, :minutes),
               2,
               :seconds
             )

      expected_new_exp_time = Utils.DateTime.adjust_cur_time(1, :hours)
      assert {:ok, retval} = Accounts.extend_session(session, %{extend_by_seconds: 3600})

      assert TestUtils.DateTime.datetimes_within?(
               retval.expires_at,
               expected_new_exp_time,
               2,
               :seconds
             )

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{expires_at: expires_at} = Accounts.get_session!(session.id)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_new_exp_time, 2, :seconds)
    end

    test "Trying to extend beyond the extendable_until point results in extension to that point" do
      session = session_fixture(%{}, %{"expires_in_seconds" => 1800, "extendable_until_seconds" => 3600})
      cur_exp_time = session.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               cur_exp_time,
               Utils.DateTime.adjust_cur_time(30, :minutes),
               2,
               :seconds
             )

      expected_new_exp_time = Utils.DateTime.adjust_cur_time(1, :hours)
      # 2,000 seconds more than what should be allowed based on our limit set above
      assert {:ok, retval} = Accounts.extend_session(session, %{extend_by_seconds: 5600})

      assert TestUtils.DateTime.datetimes_within?(
               retval.expires_at,
               expected_new_exp_time,
               2,
               :seconds
             )

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{expires_at: expires_at} = Accounts.get_session!(session.id)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_new_exp_time, 2, :seconds)
    end

    test "Not specifying extension seconds defaults to the session max by default" do
      # Initial session expires after 30 minutes
      session = session_fixture()

      assert TestUtils.DateTime.datetimes_within?(
               session.expires_at,
               Utils.DateTime.adjust_cur_time(session.max_extension_secs, :seconds),
               2,
               :seconds
             )

      expected_new_exp_time = Utils.DateTime.adjust_cur_time(1, :hours)
      assert {:ok, retval} = Accounts.extend_session(session, %{extend_by_seconds: 3600})

      assert TestUtils.DateTime.datetimes_within?(
               retval.expires_at,
               expected_new_exp_time,
               2,
               :seconds
             )

      # Query fresh from the database and verify the new expiration time persisted properly
      %Malan.Accounts.Session{expires_at: expires_at} = Accounts.get_session!(session.id)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_new_exp_time, 2, :seconds)
    end

    test "A record of extensions is kept in the database" do
      s1 =
        session_fixture(%{}, %{
          "expires_in_seconds" => 30,
          "max_extension_secs" => 360,
          "extendable_until_seconds" => 3600
        })

      user_id = s1.user_id
      session_id = s1.id
      expected_expiration_time_1 = Utils.DateTime.adjust_cur_time(30, :seconds)
      expected_extendable_until_time = Utils.DateTime.adjust_cur_time(3600, :seconds)

      assert s1.max_extension_secs == 360

      assert TestUtils.DateTime.datetimes_within?(
               s1.expires_at,
               expected_expiration_time_1,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               s1.extendable_until,
               expected_extendable_until_time,
               2,
               :seconds
             )

      assert s1.extensions == []

      # Extend the session by 1 minute
      assert {:ok, s2} =
               Accounts.extend_session(s1, %{extend_by_seconds: 60}, %{
                 authed_user_id: user_id,
                 authed_session_id: session_id
               })

      expected_expiration_time_2 = Utils.DateTime.adjust_cur_time(1, :minutes)

      # max_extension_secs should stay the same after all extensions
      assert s2.max_extension_secs == 360

      assert TestUtils.DateTime.datetimes_within?(
               s2.expires_at,
               expected_expiration_time_2,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               s2.extendable_until,
               expected_extendable_until_time,
               2,
               :seconds
             )

      assert [
               %Malan.Accounts.Session.Extension{
                 updated_at: extension1_updated_at,
                 inserted_at: extension1_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 60,
                 new_expires_at: extension1_new_expires_at,
                 old_expires_at: extension1_old_expires_at,
                 id: extension1_id
               }
             ] = s2.extensions

      assert extension1_new_expires_at == s2.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               extension1_old_expires_at,
               expected_expiration_time_1,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               extension1_new_expires_at,
               expected_expiration_time_2,
               2,
               :seconds
             )

      assert TestUtils.DateTime.within_last?(extension1_updated_at, 2, :seconds)
      assert TestUtils.DateTime.within_last?(extension1_inserted_at, 2, :seconds)

      # Extend the session a second time, by 2 minute
      assert {:ok, s3} =
               Accounts.extend_session(s2, %{extend_by_seconds: 120}, %{
                 authed_user_id: user_id,
                 authed_session_id: session_id
               })

      expected_expiration_time_3 = Utils.DateTime.adjust_cur_time(2, :minutes)

      assert s3.max_extension_secs == 360

      assert TestUtils.DateTime.datetimes_within?(
               s3.expires_at,
               expected_expiration_time_3,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               s3.extendable_until,
               expected_extendable_until_time,
               2,
               :seconds
             )

      assert [
               %Malan.Accounts.Session.Extension{
                 updated_at: extension2_updated_at,
                 inserted_at: extension2_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 120,
                 new_expires_at: extension2_new_expires_at,
                 old_expires_at: extension2_old_expires_at,
                 id: extension2_id
               },
               %Malan.Accounts.Session.Extension{
                 updated_at: ^extension1_updated_at,
                 inserted_at: ^extension1_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 60,
                 new_expires_at: ^extension1_new_expires_at,
                 old_expires_at: ^extension1_old_expires_at,
                 id: ^extension1_id
               }
             ] = s3.extensions

      assert extension2_new_expires_at == s3.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               extension2_old_expires_at,
               expected_expiration_time_2,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               extension2_new_expires_at,
               expected_expiration_time_3,
               2,
               :seconds
             )

      assert TestUtils.DateTime.within_last?(extension2_updated_at, 2, :seconds)
      assert TestUtils.DateTime.within_last?(extension2_inserted_at, 2, :seconds)

      # Extend the session a third time by 90 seconds
      assert {:ok, s4} =
               Accounts.extend_session(s3, %{extend_by_seconds: 90}, %{
                 authed_user_id: user_id,
                 authed_session_id: session_id
               })

      expected_expiration_time_4 = Utils.DateTime.adjust_cur_time(90, :seconds)

      assert s4.max_extension_secs == 360

      assert TestUtils.DateTime.datetimes_within?(
               s4.expires_at,
               expected_expiration_time_4,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               s4.extendable_until,
               expected_extendable_until_time,
               2,
               :seconds
             )

      assert [
               %Malan.Accounts.Session.Extension{
                 updated_at: extension3_updated_at,
                 inserted_at: extension3_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 90,
                 new_expires_at: extension3_new_expires_at,
                 old_expires_at: extension3_old_expires_at,
                 id: _extension3_id
               },
               %Malan.Accounts.Session.Extension{
                 updated_at: ^extension2_updated_at,
                 inserted_at: ^extension2_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 120,
                 new_expires_at: ^extension2_new_expires_at,
                 old_expires_at: ^extension2_old_expires_at,
                 id: ^extension2_id
               },
               %Malan.Accounts.Session.Extension{
                 updated_at: ^extension1_updated_at,
                 inserted_at: ^extension1_inserted_at,
                 extended_by_session: ^session_id,
                 extended_by_user: ^user_id,
                 extended_by_seconds: 60,
                 new_expires_at: ^extension1_new_expires_at,
                 old_expires_at: ^extension1_old_expires_at,
                 id: ^extension1_id
               }
             ] = s4.extensions

      assert extension3_new_expires_at == s4.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               extension3_old_expires_at,
               expected_expiration_time_3,
               2,
               :seconds
             )

      assert TestUtils.DateTime.datetimes_within?(
               extension3_new_expires_at,
               expected_expiration_time_4,
               2,
               :seconds
             )

      assert TestUtils.DateTime.within_last?(extension3_updated_at, 2, :seconds)
      assert TestUtils.DateTime.within_last?(extension3_inserted_at, 2, :seconds)
    end
  end

  # describe "teams" do
  #   alias Malan.Accounts.Team

  #   @valid_attrs %{avatar_url: "some avatar_url", description: "some description", name: "some name"}
  #   @update_attrs %{avatar_url: "some updated avatar_url", description: "some updated description", name: "some updated name"}
  #   @invalid_attrs %{avatar_url: nil, description: nil, name: nil}

  #   def team_fixture(attrs \\ %{}) do
  #     {:ok, team} =
  #       attrs
  #       |> Enum.into(@valid_attrs)
  #       |> Accounts.create_team()

  #     team
  #   end

  #   test "list_teams/0 returns all teams" do
  #     team = team_fixture()
  #     assert Accounts.list_teams() == [team]
  #   end

  #   test "get_team!/1 returns the team with given id" do
  #     team = team_fixture()
  #     assert Accounts.get_team!(team.id) == team
  #   end

  #   test "create_team/1 with valid data creates a team" do
  #     assert {:ok, %Team{} = team} = Accounts.create_team(@valid_attrs)
  #     assert team.avatar_url == "some avatar_url"
  #     assert team.description == "some description"
  #     assert team.name == "some name"
  #   end

  #   test "create_team/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Accounts.create_team(@invalid_attrs)
  #   end

  #   test "update_team/2 with valid data updates the team" do
  #     team = team_fixture()
  #     assert {:ok, %Team{} = team} = Accounts.update_team(team, @update_attrs)
  #     assert team.avatar_url == "some updated avatar_url"
  #     assert team.description == "some updated description"
  #     assert team.name == "some updated name"
  #   end

  #   test "update_team/2 with invalid data returns error changeset" do
  #     team = team_fixture()
  #     assert {:error, %Ecto.Changeset{}} = Accounts.update_team(team, @invalid_attrs)
  #     assert team == Accounts.get_team!(team.id)
  #   end

  #   test "delete_team/1 deletes the team" do
  #     team = team_fixture()
  #     assert {:ok, %Team{}} = Accounts.delete_team(team)
  #     assert_raise Ecto.NoResultsError, fn -> Accounts.get_team!(team.id) end
  #   end

  #   test "change_team/1 returns a team changeset" do
  #     team = team_fixture()
  #     assert %Ecto.Changeset{} = Accounts.change_team(team)
  #   end
  # end

  describe "phone_numbers" do
    alias Malan.Accounts.PhoneNumber

    # @valid_attrs %{number: "some number", primary: true, verified_at: "2010-04-17T14:00:00Z"}
    # @update_attrs %{number: "some updated number", primary: false, verified_at: "2011-05-18T15:01:01Z"}
    # @invalid_attrs %{number: nil, primary: nil, verified_at: nil}
    @valid_attrs %{
      "number" => "some number",
      "primary" => true,
      "verified_at" => "2010-04-17T14:00:00Z"
    }
    @update_attrs %{
      "number" => "some updated number",
      "primary" => false,
      "verified_at" => "2011-05-18T15:01:01Z"
    }
    @invalid_attrs %{"number" => nil, "primary" => nil, "verified_at" => nil}

    def phone_number_fixture(attrs \\ %{}) do
      with {:ok, user} <- Helpers.Accounts.regular_user(),
           %{} = val_attrs <- Enum.into(attrs, @valid_attrs),
           {:ok, phone_number} <- Accounts.create_phone_number(user.id, val_attrs),
           do: {:ok, user, phone_number}
    end

    test "list_phone_numbers/0 returns all phone_numbers" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert Accounts.list_phone_numbers() == [phone_number]
    end

    test "get_phone_number!/1 returns the phone_number with given id" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert Accounts.get_phone_number!(phone_number.id) == phone_number
    end

    test "create_phone_number/1 with valid data creates a phone_number" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, %PhoneNumber{} = phone_number} =
               Accounts.create_phone_number(user.id, @valid_attrs)

      assert phone_number.number == "some number"
      assert phone_number.primary == true
      # can't set verified at this way
      assert is_nil(phone_number.verified_at)
    end

    test "create_phone_number/1 with invalid data returns error changeset" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:error, %Ecto.Changeset{}} = Accounts.create_phone_number(user.id, @invalid_attrs)
    end

    test "update_phone_number/2 with valid data updates the phone_number" do
      {:ok, _user, phone_number} = phone_number_fixture()

      assert {:ok, %PhoneNumber{} = phone_number} =
               Accounts.update_phone_number(phone_number, @update_attrs)

      assert phone_number.number == "some updated number"
      assert phone_number.primary == false
      # can't set verified at this way
      assert is_nil(phone_number.verified_at)
    end

    test "update_phone_number/2 with invalid data returns error changeset" do
      {:ok, _user, phone_number} = phone_number_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_phone_number(phone_number, @invalid_attrs)

      assert phone_number == Accounts.get_phone_number!(phone_number.id)
    end

    test "delete_phone_number/1 deletes the phone_number" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert {:ok, %PhoneNumber{}} = Accounts.delete_phone_number(phone_number)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_phone_number!(phone_number.id) end
    end

    test "verify_phone_number/2" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert is_nil(phone_number.verified_at)
      {:ok, phone_number} = Accounts.verify_phone_number(phone_number, true)
      assert TestUtils.DateTime.within_last?(phone_number.verified_at, 2, :seconds)
    end
  end

  describe "addresses" do
    alias Malan.Accounts.Address

    @valid_attrs %{
      "city" => "some city",
      "primary" => true,
      "verified_at" => "2010-04-17T14:00:00Z",
      "country" => "some country",
      "line_1" => "some line_1",
      "line_2" => "some line_2",
      "name" => "some name",
      "postal" => "some postal",
      "state" => "some state"
    }
    @update_attrs %{
      "city" => "some updated city",
      "primary" => false,
      "verified_at" => "2010-04-17T14:00:00Z",
      "country" => "some updated country",
      "line_1" => "some updated line_1",
      "line_2" => "some updated line_2",
      "name" => "some updated name",
      "postal" => "some updated postal",
      "state" => "some updated state"
    }
    @invalid_attrs %{
      "city" => nil,
      "primary" => nil,
      "verified_at" => nil,
      "country" => nil,
      "line_1" => nil,
      "line_2" => nil,
      "name" => nil,
      "postal" => nil,
      "state" => nil
    }

    def address_fixture(attrs \\ %{}) do
      with {:ok, user} <- Helpers.Accounts.regular_user(),
           %{} = val_attrs <- Enum.into(attrs, @valid_attrs),
           {:ok, address} <- Accounts.create_address(user.id, val_attrs),
           do: {:ok, user, address}
    end

    test "list_addresses/0 returns all addresses" do
      {:ok, _user, address} = address_fixture()
      assert Accounts.list_addresses() == [address]
    end

    test "get_address!/1 returns the address with given id" do
      {:ok, _user, address} = address_fixture()
      assert Accounts.get_address!(address.id) == address
    end

    test "create_address/1 with valid data creates a address" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:ok, %Address{} = address} = Accounts.create_address(user.id, @valid_attrs)
      assert address.city == "some city"
      assert address.primary == true
      assert address.country == "some country"
      assert address.line_1 == "some line_1"
      assert address.line_2 == "some line_2"
      assert address.name == "some name"
      assert address.postal == "some postal"
      assert address.state == "some state"
      # can't set verified at this way
      assert is_nil(address.verified_at)
    end

    test "create_address/1 with invalid data returns error changeset" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:error, %Ecto.Changeset{}} = Accounts.create_address(user.id, @invalid_attrs)
    end

    test "update_address/2 with valid data updates the address" do
      {:ok, _user, address} = address_fixture()
      assert {:ok, %Address{} = address} = Accounts.update_address(address, @update_attrs)
      assert address.city == "some updated city"
      assert address.primary == false
      assert address.country == "some updated country"
      assert address.line_1 == "some updated line_1"
      assert address.line_2 == "some updated line_2"
      assert address.name == "some updated name"
      assert address.postal == "some updated postal"
      assert address.state == "some updated state"
      # can't set verified at this way
      assert is_nil(address.verified_at)
    end

    test "update_address/2 with invalid data returns error changeset" do
      {:ok, _user, address} = address_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_address(address, @invalid_attrs)
      assert address == Accounts.get_address!(address.id)
    end

    test "delete_address/1 deletes the address" do
      {:ok, _user, address} = address_fixture()
      assert {:ok, %Address{}} = Accounts.delete_address(address)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_address!(address.id) end
    end

    test "verify_address/2" do
      {:ok, _user, address} = address_fixture()
      assert is_nil(address.verified_at)
      {:ok, address} = Accounts.verify_address(address, true)
      assert TestUtils.DateTime.within_last?(address.verified_at, 2, :seconds)
    end
  end

  describe "logs" do
    alias Malan.Accounts.Log

    import Malan.AccountsFixtures

    @invalid_attrs %{"type" => nil, "verb" => nil, "what" => nil, "when" => nil}

    test "list_logs/0 returns all logs" do
      {:ok, _user, _session, log} = log_fixture()
      assert Accounts.list_logs(0, 10) == [log_fixture_to_retrieved(log)]
    end

    test "list_logs/1 returns all logs for user" do
      {:ok, u1, _s1, l1} = log_fixture()
      {:ok, _u2, _s2, _l2} = log_fixture()
      assert Accounts.list_logs(u1.id, 0, 10) == [log_fixture_to_retrieved(l1)]
    end

    test "get_log!/1 returns the log with given id" do
      {:ok, _user, _session, log} = log_fixture()

      assert Accounts.get_log!(log.id) ==
               log_fixture_to_retrieved(log)
    end

    test "get_log_by/1 returns the log matching the param" do
      {:ok, user, _session, log} = log_fixture()

      assert Accounts.get_log_by(user_id: user.id) ==
               log_fixture_to_retrieved(log)
    end

    test "get_log_by/1 returns nil if no results" do
      assert Accounts.get_log_by(user_id: "f0e2c256-1827-4c34-9e64-d890b959ee04") == nil
    end

    test "get_log_by/1 raises if multiple results" do
      {:ok, u1, _s1, _l1} = log_fixture()
      {:ok, _u2, _s2, _l2} = log_fixture(%{"user_id" => u1.id})

      assert_raise Ecto.MultipleResultsError, fn ->
        Accounts.get_log_by(user_id: u1.id)
      end
    end

    test "get_log_by!/1 returns the log matching the param" do
      {:ok, user, _session, tf} = log_fixture()

      assert log_fixture_to_retrieved(tf) ==
               Accounts.get_log_by!(user_id: user.id)
    end

    test "get_log_by!/1 raises if no results" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_log_by!(user_id: "f0e2c256-1827-4c34-9e64-d890b959ee04")
      end
    end

    test "get_log_by!/1 raises if multiple results" do
      {:ok, u1, _s1, _l1} = log_fixture()
      {:ok, _u2, _s2, _l2} = log_fixture(%{"user_id" => u1.id})

      assert_raise Ecto.MultipleResultsError, fn ->
        Accounts.get_log_by!(user_id: u1.id)
      end
    end

    test "create_log/1 with valid data creates a log" do
      valid_attrs = %{
        "type" => "sessions",
        "verb" => "DELETE",
        "what" => "some what",
        "when" => ~U[2021-12-22 21:02:00Z]
      }

      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      assert {:ok, %Log{} = log} =
               Accounts.create_log(
                 true,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "1.1.1.1",
                 %{},
                 valid_attrs
               )

      assert log.type == "sessions"
      assert log.verb == "DELETE"
      assert log.what == "some what"
      assert log.when == ~U[2021-12-22 21:02:00Z]
    end

    test "create_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Accounts.create_log(nil, nil, nil, nil, nil, nil, @invalid_attrs)
    end

    test "update_log/2 with valid data raises a Malan.ObjectIsImmutable exception" do
      {:ok, _user, _session, log} = log_fixture()

      update_attrs = %{
        type: "sessions",
        verb: "PUT",
        what: "some updated what",
        when: ~U[2021-12-23 21:02:00Z]
      }

      assert_raise Malan.ObjectIsImmutable, fn ->
        Accounts.update_log(log, update_attrs)
      end

      assert log_fixture_to_retrieved(log) ==
               Accounts.get_log!(log.id)
    end

    test "update_log/2 with invalid data raises a Malan.ObjectIsImmutable exception" do
      {:ok, _user, _session, tf} = log_fixture()

      assert_raise Malan.ObjectIsImmutable, fn ->
        Accounts.update_log(tf, @invalid_attrs)
      end

      assert log_fixture_to_retrieved(tf) == Accounts.get_log!(tf.id)
    end

    test "delete_log/1 raises a Malan.ObjectIsImmutable exception" do
      {:ok, _user, _session, log} = log_fixture()

      assert_raise Malan.ObjectIsImmutable, fn ->
        Accounts.delete_log(log)
      end

      assert log_fixture_to_retrieved(log) ==
               Accounts.get_log!(log.id)
    end

    test "get_log_user/1" do
      {:ok, user, _session, log} = log_fixture()
      user_id = user.id
      assert %{user_id: ^user_id} = Accounts.get_log_user(log.id)
    end
  end
end
