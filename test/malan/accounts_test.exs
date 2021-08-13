defmodule Malan.AccountsTest do
  use Malan.DataCase, async: true

  alias Malan.Accounts
  alias Malan.Accounts.TermsOfService, as: ToS
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Utils
  alias Malan.Test.Utils, as: TestUtils
  alias Malan.Test.Helpers

  @user1_attrs %{email: "user1@email.com", username: "someusername1", first_name: "First Name1", last_name: "Last Name1", nick_name: "user nick1"}
  @user2_attrs %{email: "user2@email.com", username: "someusername2", first_name: "First Name2", last_name: "Last Name2", nick_name: "user nick2"}
  @update_attrs %{password: "some updated password", preferences: %{theme: "light"}, roles: [], sex: "other", gender: "male"}
  @invalid_attrs %{email: nil, email_verified: nil, password: nil, preferences: nil, roles: nil, username: nil}

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(@user1_attrs)
      |> Accounts.register_user()

    user
  end

  describe "users" do
    alias Malan.Accounts.User

    test "list_users/0 returns all users" do
      user = %{user_fixture() | password: nil, custom_attrs: %{}}
      # password should be nil coming from database since that's a virtual field
      users = Accounts.list_users()
      assert is_list(users)
      assert Enum.member?((1..3), length(users))
      #assert(length(users) == 1 || length(users) == 3) # flakey based on seeds.exs adding 2
      assert Enum.any?(users, fn (u) -> user == u end)
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == %{user | password: nil, tos_accept_events: [], custom_attrs: %{}}
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
      assert us.password == nil # important check since password is hashed
      assert us.preferences == user.preferences
      assert us.roles == user.roles
      assert us.tos_accept_events == []
      assert us.custom_attrs == %{}
      assert us.username == user.username
    end

    test "register_user/1 can have password specified" do
      user1 = Map.put(@user1_attrs, :password, "examplepassword")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.password == "examplepassword"
      {:ok, user_id} = Accounts.authenticate_by_username_pass(user.username, user.password)
      assert user_id == user.id
    end

    test "register_user/1 can have sex specified" do
      user1 = Map.put(@user1_attrs, :sex, "female")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.sex == "female"
      assert user.sex_enum == Malan.Accounts.User.Sex.to_i(user.sex)
      assert user.sex_enum == 1

      user2 = Map.put(@user2_attrs, :sex, "incorrect")
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(user2)

      user2 = Map.put(@user2_attrs, :sex, "male")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.sex == "male"
      assert user.sex_enum == Malan.Accounts.User.Sex.to_i(user.sex)
      assert user.sex_enum == 0
    end

    test "register_user/1 can have ethnicity specified" do
      user1 = Map.put(@user1_attrs, :ethnicity, "Hispanic or Latinx")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.ethnicity == "Hispanic or Latinx"
      assert user.ethnicity_enum == Malan.Accounts.User.Ethnicity.to_i(user.ethnicity)
      assert user.ethnicity_enum == 0

      user2 = Map.put(@user2_attrs, :ethnicity, "incorrect")
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(user2)

      user2 = Map.put(@user2_attrs, :ethnicity, "not hispanic or latinx")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.ethnicity == "not hispanic or latinx"
      assert user.ethnicity_enum == Malan.Accounts.User.Ethnicity.to_i(user.ethnicity)
      assert user.ethnicity_enum == 1
    end

    test "register_user/1 can have gender specified" do
      user1 = Map.put(@user1_attrs, :gender, "female")
      assert {:ok, %User{} = user} = Accounts.register_user(user1)
      assert user.gender == "female"
      assert user.gender_enum == Malan.Accounts.User.Gender.to_i(user.gender)
      assert user.gender_enum == 51
      user2 = Map.put(@user2_attrs, :gender, "male")
      assert {:ok, %User{} = user} = Accounts.register_user(user2)
      assert user.gender == "male"
      assert user.gender_enum == Malan.Accounts.User.Gender.to_i(user.gender)
      assert user.gender_enum == 50
    end

    test "register_user/1 rejects invalid gender" do
      user1 = Map.put(@user1_attrs, :gender, "fake")
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.register_user(user1)
      assert changeset.valid? == false
      assert errors_on(changeset).gender
             |> Enum.any?(fn (x) -> x =~ ~r/gender.is.invalid/ end)
    end

    test "admin can trigger a password reset with random value" do
      assert {:ok, ru} = Helpers.Accounts.regular_user()
      assert {:ok, user_id} = Accounts.authenticate_by_username_pass(ru.username, ru.password)
      assert {:ok, user} = Accounts.admin_update_user(ru, %{password_reset: true})
      assert user.password =~ ~r/[A-Za-z0-9]{10}/
      assert {:ok, ^user_id} = Accounts.authenticate_by_username_pass(ru.username, ru.password)
    end

    test "register_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.password == "some updated password"
      assert %{theme: "light", id: _} = user.preferences
      assert %{
        user | password: nil, sex: nil, sex_enum: 2, gender: nil, gender_enum: 50, custom_attrs: %{}
      } == Accounts.get_user!(user.id)
      assert user.sex == "other"
    end

    test "update_user_password/2 with valid data updates the user's password" do
      %User{id: user_id} = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user_password(user_id, "some updated password")
      assert user.password == "some updated password"
      assert %{ user | password: nil } == Accounts.get_user!(user_id)
    end

    test "update_user/2 disallows setting mutable fields" do
      # attempt to change and then do a get from the db to
      # verify no changes
      uf = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(uf, %{
        email: "shineshine@hushhush.com",
        username: "TooShyShy"
      })
      assert user.email == "user1@email.com"
      assert user.username == "someusername1"
      assert %{uf | password: nil, tos_accept_events: [], custom_attrs: %{}} == Accounts.get_user!(user.id)
    end

    test "update_user/2 disallows settings ToS or Email verify" do
      uf = user_fixture()
%{email: "some@email.com", username: "someusername"}
      assert {:ok, %User{} = user} = Accounts.update_user(uf, %{
        email_verified: DateTime.from_naive!(~N[2011-05-18T15:01:01Z], "Etc/UTC"),
        tos_accept_events: DateTime.from_naive!(~N[2011-05-18T15:01:01Z], "Etc/UTC")
      })
      assert user.email_verified == nil
      assert user.tos_accept_events == []
      assert %{uf | password: nil, tos_accept_events: [], custom_attrs: %{}} == Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, @invalid_attrs)
      assert changeset.valid? == false
      assert errors_on(changeset).password
             |> Enum.any?(fn (x) -> x =~ ~r/can.t.be.blank/ end)
      assert %{user | password: nil, tos_accept_events: [], custom_attrs: %{}} == Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid sex returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, %{sex: "Y"})
      assert changeset.valid? == false
      assert errors_on(changeset).sex
             |> Enum.any?(fn (x) -> x =~ ~r/sex.is.invalid/ end)
      assert %{user | gender: nil, password: nil, tos_accept_events: [], custom_attrs: %{}} == Accounts.get_user!(user.id)
    end

    test "update_user/2 with invalid gender returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, %{gender: "Y"})
      assert changeset.valid? == false
      assert errors_on(changeset).gender
             |> Enum.any?(fn (x) -> x =~ ~r/gender.is.invalid/ end)
      assert %{user | gender: nil, password: nil, tos_accept_events: [], custom_attrs: %{}} == Accounts.get_user!(user.id)
    end

    #test "update_user/2 can be used to accept the ToS" do
    #  user1 = user_fixture()
    #  assert user1.tos_accept_events == []
    #  assert {:ok, %User{} = user2} = Accounts.update_user(user1, %{accept_tos: true})
    #  assert user2.password =~ ~r/[A-Za-z0-9]{10}/
    #  assert TestUtils.DateTime.within_last?(user2.tos_accept_events, 5, :seconds)
    #  assert %{ user2 | password: nil, accept_tos: nil } == Accounts.get_user!(user2.id)
    #end

    #test "update_user/2 doesn't accept ToS when set to false" do
    #  user = user_fixture()
    #  assert {:ok, %User{} = user} = Accounts.update_user(
    #    user, %{accept_tos: false, preferences: %{theme: "undark"}}
    #  )
    #  assert user.tos_accept_events == []
    #  assert user.preferences == %{theme: "undark"}
    #  assert %{
    #    user | password: nil, accept_tos: nil, preferences: %{"theme" => "undark"}, tos_accept_events: []
    #  } == Accounts.get_user!(user.id)
    #end

    test "is_admin/1 returns false when not an admin" do
      user = user_fixture()
      assert {:ok, false} = Accounts.user_is_admin?(user.id)
    end

    test "user_accept_tos/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_accept_tos(orig.id)
      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version}
        = List.first(user.tos_accept_events)
      assert tos_version == ToS.current_version()
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert user.latest_tos_accept_ver == ToS.current_version()
    end

    test "user_reject_tos/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_reject_tos(orig.id)
      assert %{accept: false, id: id, timestamp: timestamp, tos_version: tos_version}
        = List.first(user.tos_accept_events)
      assert tos_version == ToS.current_version()
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert user.latest_tos_accept_ver == nil
    end

    test "user_accept_tos/1 and user_reject_tos/1 prepends to the array" do
      orig = user_fixture()

      assert {:ok, u1} = Accounts.user_accept_tos(orig.id)
      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version}
        = List.first(u1.tos_accept_events)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)

      assert {:ok, u2} = Accounts.user_accept_tos(orig.id)
      assert length(u2.tos_accept_events) == 2
      assert %{accept: true, id: id, timestamp: timestamp, tos_version: tos_version}
        = Enum.at(u2.tos_accept_events, 0)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u2.latest_tos_accept_ver == ToS.current_version()

      assert {:ok, u3} = Accounts.user_reject_tos(orig.id)
      assert length(u2.tos_accept_events) == 2
      assert %{accept: false, id: id, timestamp: timestamp, tos_version: tos_version}
        = Enum.at(u3.tos_accept_events, 0)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert tos_version == ToS.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u3.latest_tos_accept_ver == nil
    end

    test "user_accept_privacy_policy/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_accept_privacy_policy(orig.id)
      assert %{accept: true, id: id, timestamp: timestamp, privacy_policy_version: ppv}
        = List.first(user.privacy_policy_accept_events)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert ppv == PrivacyPolicy.current_version()
      assert user.latest_pp_accept_ver == PrivacyPolicy.current_version()
    end

    test "user_reject_privacy_policy/2 works" do
      orig = user_fixture()

      assert {:ok, user} = Accounts.user_reject_privacy_policy(orig.id)
      assert %{accept: false, id: id, timestamp: timestamp, privacy_policy_version: ppv}
        = List.first(user.privacy_policy_accept_events)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert ppv == PrivacyPolicy.current_version()
      assert user.latest_pp_accept_ver == nil
    end

    test "user_accept_privacy_policy/1 and user_reject_privacy_policy/1 prepends to the array" do
      orig = user_fixture()

      assert {:ok, u1} = Accounts.user_accept_privacy_policy(orig.id)
      assert %{accept: true, id: id, timestamp: timestamp, privacy_policy_version: privacy_policy_version}
        = List.first(u1.privacy_policy_accept_events)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert privacy_policy_version == PrivacyPolicy.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)

      assert {:ok, u2} = Accounts.user_accept_privacy_policy(orig.id)
      assert length(u2.privacy_policy_accept_events) == 2
      assert %{accept: true, id: id, timestamp: timestamp, privacy_policy_version: privacy_policy_version}
        = Enum.at(u2.privacy_policy_accept_events, 0)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
      assert privacy_policy_version == PrivacyPolicy.current_version()
      assert TestUtils.DateTime.within_last?(timestamp, 2, :seconds)
      assert u2.latest_pp_accept_ver == PrivacyPolicy.current_version()

      assert {:ok, u3} = Accounts.user_reject_privacy_policy(orig.id)
      assert length(u2.privacy_policy_accept_events) == 2
      assert %{accept: false, id: id, timestamp: timestamp, privacy_policy_version: privacy_policy_version}
        = Enum.at(u3.privacy_policy_accept_events, 0)
      assert id =~ ~r/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/
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
      assert {:ok, %Accounts.User{} = updated_user} = Accounts.update_user(user, %{roles: ["admin", "moderator"]})
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

    test "Usernames must be unique on creation" do
      user1_attrs = %{@user1_attrs | username: "someusername" }
      user2_attrs = %{@user2_attrs | username: "someusername" }
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.username == "someusername"
      assert user1.email == "user1@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/has already been taken/ end)
    end

    test "Usernames must be unique and case insensitive" do
      user1_attrs = %{@user1_attrs | username: "someusername" }
      user2_attrs = %{@user2_attrs | username: "SoMeUsErNAmE" }
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.username == "someusername"
      assert user1.email == "user1@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/has already been taken/ end)
    end

    test "Email must be unique on creation" do
      user1_attrs = %{@user1_attrs | email: "some@email.com" }
      user2_attrs = %{@user2_attrs | email: "some@email.com" }
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.email == "some@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).email
             |> Enum.any?(fn (x) -> x =~ ~r/has already been taken/ end)
    end

    test "Email must be unique on creation and case insensitive" do
      user1_attrs = %{@user1_attrs | email: "some@email.com" }
      user2_attrs = %{@user2_attrs | email: "SOME@email.com" }
      assert {:ok, %User{} = user1} = Accounts.register_user(user1_attrs)
      assert user1.email == "some@email.com"
      assert {:error, changeset} = Accounts.register_user(user2_attrs)

      assert errors_on(changeset).email
             |> Enum.any?(fn (x) -> x =~ ~r/has already been taken/ end)
    end

    test "Can set arbitrary JSON on a user" do
      custom_attrs = %{"some_val" => "some_val", "second" => %{"third" => "third"}}
      uf = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(uf, %{custom_attrs: custom_attrs})
      assert %{"some_val" => "some_val", "second" => %{"third" => "third"}} = user.custom_attrs
      assert %{user | password: nil} == Accounts.get_user!(user.id)
    end

    test "update_user_password/2 updates the user's password" do
      new_password = "sodabubbles"
      %User{id: user_id} = uf = user_fixture()
      {:ok, user} = Accounts.update_user_password(uf.id, new_password)
      assert user.password != uf.password
      assert user.password == new_password
      assert %{ user | password: nil } == Accounts.get_user!(user_id)
    end

    test "generate_password_reset/1 adds a reset token to the database and an expiration" do
      uf = user_fixture()
      user = Accounts.get_user(uf.id)
      assert is_nil(uf.password_reset_token)
      assert is_nil(uf.password_reset_token_hash)
      assert is_nil(uf.password_reset_token_expires_at)
      {:ok, updated} = Accounts.generate_password_reset(user)
      assert %{ updated | password_reset_token: nil, password_reset_token_hash: nil, password_reset_token_expires_at: nil } == user
      assert updated.password_reset_token
      assert updated.password_reset_token_hash
      assert updated.password_reset_token_expires_at
      uuser = Accounts.get_user(updated.id)
      assert is_nil(uuser.password_reset_token) # should be blank now
      assert uuser.password_reset_token_hash
      assert uuser.password_reset_token_expires_at
    end

    test "validate_password_reset_token/2 logic test: returns properly with no token" do
      uf = user_fixture() # this won't have a password reset token yet
      assert {:error, :missing_password_reset_token} = Accounts.validate_password_reset_token(uf, "")
      assert {:error, :missing_password_reset_token} = Accounts.validate_password_reset_token(uf, nil)
      assert {:error, :missing_password_reset_token} = Accounts.validate_password_reset_token(uf, "abcde")
    end

    test "validate_password_reset_token/2 logic test: returns properly incorrect token" do
      uf = user_fixture()
           |> Map.merge(%{
             password_reset_token: "ohai",
             password_reset_token_hash: "hellow",
             password_reset_token_expires_at: Utils.DateTime.adjust_cur_time(1, :minutes)
           })
      assert {:error, :invalid_password_reset_token} = Accounts.validate_password_reset_token(uf, "helloworld")
      assert {:error, :invalid_password_reset_token} = Accounts.validate_password_reset_token(uf, "42")
    end

    test "validate_password_reset_token/2 logic test: returns properly with valid token" do
      uf = user_fixture()
      {:ok, user} = Accounts.generate_password_reset(uf)
      assert {:ok} = Accounts.validate_password_reset_token(user, user.password_reset_token)
    end

    test "validate_password_reset_token/2 logic test: returns expired when expired" do
      uf = user_fixture()
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
      assert {:error, :missing_password_reset_token} = Accounts.validate_password_reset_token(cleared_user, user.password_reset_token)
      assert {:error, :missing_password_reset_token} = Accounts.validate_password_reset_token(cleared_user, cleared_user.password_reset_token)
    end

    test "get_user_by_password_reset_token/1" do
      # This is tested by the user controller test
    end

    test "get_user_by_id_or_username/1" do
      uf = user_fixture()
      u1 = Accounts.get_user_by_id_or_username!(uf.username)
      assert %{ uf | custom_attrs: %{}, password: nil } == u1
      u2 = Accounts.get_user_by_id_or_username!(uf.id)
      assert %{ uf | custom_attrs: %{}, password: nil } == u2
      assert u1 == u2
    end
  end

  describe "sessions" do
    alias Malan.Accounts.Session

    def session_fixture(user_attrs \\ %{}, session_attrs \\ %{}) do
      user = user_fixture(user_attrs)

      {:ok, session} = Accounts.create_session(
        user.username,
        user.password,
        Map.merge(%{"ip_address" => "192.168.2.200"}, session_attrs)
      )

      session
    end

    def session_valid_fixture(args \\ %{}) do
      %{
        user_id: "user_id",
        session_id: "session_id",
        expires_at: Utils.DateTime.adjust_cur_time(7, :days),
        revoked_at: nil,
        roles: ["user"],
        latest_tos_accept_ver: "1",
        latest_pp_accept_ver: "2",
      }
      |> Map.merge(args)
    end

    test "list_sessions/0 returns all sessions" do
      session = %{session_fixture() | api_token: nil}
      assert Accounts.list_sessions() == [session]
    end

    test "get_session!/1 returns the session with given id" do
      session = session_fixture()
      assert Accounts.get_session!(session.id) == %{session | api_token: nil}
    end

    test "create_session/1 with valid data creates a session" do
      user = user_fixture()
      assert {:ok, %Session{} = session} = Accounts.create_session(user.username, user.password, %{"ip_address" => "192.168.2.200"})
      # API token should be included after creation, but not after that
      assert session.api_token =~ ~r/[A-Za-z0-9]{10}/
      assert TestUtils.DateTime.within_last?(session.authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, session.authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), session.expires_at, :second))
      assert session.ip_address == "192.168.2.200"
      assert session.revoked_at == nil
    end

    test "create_session/1 with expires_never at true expires over 200 years from now" do
      user = user_fixture()
      assert {:ok, %Session{} = session} = Accounts.create_session(
        user.username,
        user.password,
        %{"never_expires" => true, "ip_address" => "192.168.2.200"}
      )
      assert DateTime.diff(session.expires_at, DateTime.utc_now) > 5_000_000_000
      assert {:ok, _, _, _, _, _, _} = Accounts.validate_session(session.api_token)
    end

    test "create_session/1 with expires_in_seconds expires at specified time" do
      user = user_fixture()
      assert {:ok, %Session{} = session} = Accounts.create_session(
        user.username,
        user.password,
        %{"expires_in_seconds" => -120, "ip_address" => "192.168.2.200"}
      )
      assert !TestUtils.DateTime.within_last?(session.expires_at, 119, :seconds)
      assert  TestUtils.DateTime.within_last?(session.expires_at, 125, :seconds)
      assert {:error, :expired} = Accounts.validate_session(session.api_token)
    end

    test "create_session/1 never_expire set to 'false' doesn't affect stuff" do
      user = user_fixture()
      assert {:ok, %Session{} = session} = Accounts.create_session(
        user.username,
        user.password,
        %{"never_expires" => false, "expires_in_seconds" => -120, "ip_address" => "192.168.2.200"}
      )
      assert !TestUtils.DateTime.within_last?(session.expires_at, 119, :seconds)
      assert  TestUtils.DateTime.within_last?(session.expires_at, 125, :seconds)
      assert {:error, :expired} = Accounts.validate_session(session.api_token)
    end

    test "create_session/1 doesn't allow specifying user ID" do
      user1 = user_fixture(%{username: "username1"})
      user2 = user_fixture(%{username: "username2", email: "username2@example.com"})
      assert {:ok, session} = Accounts.create_session(user1.username, user1.password, %{"user_id" => user2.id, "ip_address" => "192.168.2.200"})
      assert user2.id != user1.id
      assert session.user_id == user1.id
    end

    test "get_user_id_pass_hash_by_username/1 returns [user_id, password_hash] on success" do
      user = user_fixture()
      assert {user_id, password_hash} = Accounts.get_user_id_pass_hash_by_username(user.username)
      assert user_id == user.id
      assert password_hash == user.password_hash
    end

    test "get_user_id_pass_hash_by_username/1 returns nil on username not found" do
      assert nil == Accounts.get_user_id_pass_hash_by_username("notarealusernameatall")
    end

    test "create_session/1 with incorrect pass returns {:error, :unauthorized}" do
      user = user_fixture()
      assert {:error, :unauthorized} = Accounts.create_session(user.username, "nottherightpassword", "192.168.2.200")
    end

    test "create_session/1 with non-existent user returns {:error, :not_a_user}" do
      assert {:error, :not_a_user} = Accounts.create_session("notarealusernameatall", "nottherightpassword", "192.168.2.200")
    end

    test "delete_session/1 revokes the session" do
      session = session_fixture()
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      sesh = Accounts.get_session!(session.id)
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, sesh.revoked_at, :second))
    end

    test "validate_session/1 returns a user id, roles, and expires_at when the session is valid" do
      session = session_fixture(%{username: "randomusername1"})
      assert {:ok, user_id, session_id, roles, exp, tos, pp} = Accounts.validate_session(session.api_token)
      assert user_id == session.user_id
      assert session_id == session.id
      assert roles == ["user"]
      assert TestUtils.DateTime.first_after_second_within?(Utils.DateTime.adjust_cur_time(1, :weeks), exp, 3, :seconds)
      assert is_nil(tos)
      assert is_nil(pp)
    end

    test "validate_session/1 return an error when the session is revoked" do
      session = session_fixture(%{username: "randomusername2"})
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      assert {:error, :revoked} = Accounts.validate_session(session.api_token)
    end

    test "validate_session/1 return an error when the session is revoked even when token expires infinitely" do
      session = session_fixture(%{username: "randomusername2"}, %{"never_expires" => false})
      assert {:ok, %Session{}} = Accounts.delete_session(session)
      assert {:error, :revoked} = Accounts.validate_session(session.api_token)
    end

    test "validate_session/1 return an error when the session is expired" do
      session = session_fixture(%{username: "randomusername3"}, %{"expires_in_seconds" => -5})
      assert {:error, :expired} = Accounts.validate_session(session.api_token)
    end

    test "validate_session/1 return an error when the session token does not exist" do
      assert {:error, :not_found} = Accounts.validate_session("notavalidtoken")
    end

    test "update_user/2 can be used to update user preferences" do
      user = user_fixture()
      update_user_prefs = %{
        preferences: %{
          invalid: "invalid",
          theme: "dark",
        }
      }
      assert {:ok, %Accounts.User{} = updated_user} = Accounts.update_user(user, update_user_prefs)
      assert %{id: _, theme: "dark"} = updated_user.preferences
      assert false == Map.has_key?(updated_user.preferences, :invalid)
    end

    test "update_user/2 invalid theme is rejected" do
      user = user_fixture()
      update_user_prefs = %{
        preferences: %{
          theme: "invalid",
        }
      }
      assert {:error, changeset} = Accounts.update_user(user, update_user_prefs)
      assert errors_on(changeset).preferences.theme
             |> Enum.any?(fn (x) -> x =~ ~r/valid.themes.are/i end)
    end

    test "update_user/2 overwrites old preferences" do
      user = user_fixture()
      update_user_prefs = %{
        preferences: %{
          theme: "dark",
        }
      }
      assert {:ok, %Accounts.User{} = updated_user} = Accounts.update_user(user, update_user_prefs)
      assert %{id: _, theme: "dark"} = updated_user.preferences
      assert false == Map.has_key?(updated_user.preferences, :invalid)

      second_user_prefs = %{
        preferences: %{
          theme: "dark",
          default_sans: "something",
        }
      }
      assert {:ok, %Accounts.User{} = updated_user} = Accounts.update_user(user, second_user_prefs)
      assert %{id: _, theme: "dark", default_sans: "something"} = updated_user.preferences
    end

    test "revoke_active_sessions/1 revokes all session for the user except non-expiring" do
      {:ok, user} = Helpers.Accounts.regular_user()

      sessions = 1..3 |> Enum.map(fn (_i) ->
        {:ok, session} = Helpers.Accounts.create_session(user)
        session
      end)
      {:ok, forever_session} = Helpers.Accounts.create_session(user, %{"never_expires" => true})
      assert {:ok, _, _, _, exp, _, _} = Accounts.validate_session(forever_session.api_token)
      assert DateTime.compare(
        Utils.DateTime.adjust_cur_time(36500, :days), exp
      ) == :lt

      Enum.each(sessions, fn (s) ->
        assert {:ok, user_id, _, _, _, _, _} = Accounts.validate_session(s.api_token)
        assert user_id == user.id
      end)

      Accounts.revoke_active_sessions(user)

      Enum.each(sessions, fn (s) ->
        assert {:error, :revoked} = Accounts.validate_session(s.api_token)
      end)
    end

    test "user_add_role/2 adds the role to the user" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:ok, false} = Accounts.user_is_admin?(user.id)
      Accounts.user_add_role("admin", user.id)
      assert {:ok, true} = Accounts.user_is_admin?(user.id)
    end

    test "session_valid?/1 with nil returns error not found" do
      assert {:error, :not_found} = Accounts.session_valid?(nil)
    end

    test "session_valid?/1 with map revoked tokens always shows revoked" do
      assert {:error, :revoked} = Accounts.session_valid?(session_valid_fixture(%{revoked_at: DateTime.utc_now}))
      assert {:error, :revoked} = Accounts.session_valid?(session_valid_fixture(%{expires_at: Utils.DateTime.adjust_cur_time(-2, :hours), revoked_at: DateTime.utc_now}))
    end

    test "session_valid?/1 returns expected structure when valid" do
      args = %{
        user_id: user_id,
        session_id: session_id,
        expires_at: expires_at,
        revoked_at: _revoked_at,
        roles: roles,
        latest_tos_accept_ver: latest_tos_accept_ver,
        latest_pp_accept_ver: latest_pp_accept_ver,
      } = %{
        user_id: "123",
        session_id: "abc",
        expires_at: Utils.DateTime.adjust_cur_time(2, :days),
        revoked_at: nil,
        roles: ["user"],
        latest_tos_accept_ver: "12",
        latest_pp_accept_ver: "13",
      }

      assert {:ok, ^user_id, ^session_id, ^roles, ^expires_at, ^latest_tos_accept_ver, ^latest_pp_accept_ver} = Accounts.session_valid?(args)
    end

    test "session_valid?/1 with map expired but not revoked is expired" do
      assert {:error, :expired} = Accounts.session_valid?(session_valid_fixture(%{expires_at: Utils.DateTime.adjust_cur_time(-2, :hours), revoked_at: nil}))
    end

    test "session_valid?/1 with forever token is valid" do
      assert {:ok, _, _, _, _, _, _} = Accounts.session_valid?(session_valid_fixture(%{expires_at: Utils.DateTime.distant_future, revoked_at: nil}))
    end

  end

  #describe "teams" do
  #  alias Malan.Accounts.Team

  #  @valid_attrs %{avatar_url: "some avatar_url", description: "some description", name: "some name"}
  #  @update_attrs %{avatar_url: "some updated avatar_url", description: "some updated description", name: "some updated name"}
  #  @invalid_attrs %{avatar_url: nil, description: nil, name: nil}

  #  def team_fixture(attrs \\ %{}) do
  #    {:ok, team} =
  #      attrs
  #      |> Enum.into(@valid_attrs)
  #      |> Accounts.create_team()

  #    team
  #  end

  #  test "list_teams/0 returns all teams" do
  #    team = team_fixture()
  #    assert Accounts.list_teams() == [team]
  #  end

  #  test "get_team!/1 returns the team with given id" do
  #    team = team_fixture()
  #    assert Accounts.get_team!(team.id) == team
  #  end

  #  test "create_team/1 with valid data creates a team" do
  #    assert {:ok, %Team{} = team} = Accounts.create_team(@valid_attrs)
  #    assert team.avatar_url == "some avatar_url"
  #    assert team.description == "some description"
  #    assert team.name == "some name"
  #  end

  #  test "create_team/1 with invalid data returns error changeset" do
  #    assert {:error, %Ecto.Changeset{}} = Accounts.create_team(@invalid_attrs)
  #  end

  #  test "update_team/2 with valid data updates the team" do
  #    team = team_fixture()
  #    assert {:ok, %Team{} = team} = Accounts.update_team(team, @update_attrs)
  #    assert team.avatar_url == "some updated avatar_url"
  #    assert team.description == "some updated description"
  #    assert team.name == "some updated name"
  #  end

  #  test "update_team/2 with invalid data returns error changeset" do
  #    team = team_fixture()
  #    assert {:error, %Ecto.Changeset{}} = Accounts.update_team(team, @invalid_attrs)
  #    assert team == Accounts.get_team!(team.id)
  #  end

  #  test "delete_team/1 deletes the team" do
  #    team = team_fixture()
  #    assert {:ok, %Team{}} = Accounts.delete_team(team)
  #    assert_raise Ecto.NoResultsError, fn -> Accounts.get_team!(team.id) end
  #  end

  #  test "change_team/1 returns a team changeset" do
  #    team = team_fixture()
  #    assert %Ecto.Changeset{} = Accounts.change_team(team)
  #  end
  #end

  describe "phone_numbers" do
    alias Malan.Accounts.PhoneNumber

    #@valid_attrs %{number: "some number", primary: true, verified: "2010-04-17T14:00:00Z"}
    #@update_attrs %{number: "some updated number", primary: false, verified: "2011-05-18T15:01:01Z"}
    #@invalid_attrs %{number: nil, primary: nil, verified: nil}
    @valid_attrs %{"number" => "some number", "primary" => true, "verified" => "2010-04-17T14:00:00Z"}
    @update_attrs %{"number" => "some updated number", "primary" => false, "verified" => "2011-05-18T15:01:01Z"}
    @invalid_attrs %{"number" => nil, "primary" => nil, "verified" => nil}

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
      assert {:ok, %PhoneNumber{} = phone_number} = Accounts.create_phone_number(user.id, @valid_attrs)
      assert phone_number.number == "some number"
      assert phone_number.primary == true
      assert phone_number.verified == DateTime.from_naive!(~N[2010-04-17T14:00:00Z], "Etc/UTC")
    end

    test "create_phone_number/1 with invalid data returns error changeset" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert {:error, %Ecto.Changeset{}} = Accounts.create_phone_number(user.id, @invalid_attrs)
    end

    test "update_phone_number/2 with valid data updates the phone_number" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert {:ok, %PhoneNumber{} = phone_number} = Accounts.update_phone_number(phone_number, @update_attrs)
      assert phone_number.number == "some updated number"
      assert phone_number.primary == false
      assert phone_number.verified == DateTime.from_naive!(~N[2011-05-18T15:01:01Z], "Etc/UTC")
    end

    test "update_phone_number/2 with invalid data returns error changeset" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_phone_number(phone_number, @invalid_attrs)
      assert phone_number == Accounts.get_phone_number!(phone_number.id)
    end

    test "delete_phone_number/1 deletes the phone_number" do
      {:ok, _user, phone_number} = phone_number_fixture()
      assert {:ok, %PhoneNumber{}} = Accounts.delete_phone_number(phone_number)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_phone_number!(phone_number.id) end
    end
  end
end
