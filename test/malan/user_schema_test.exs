defmodule Malan.UserSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Accounts
  alias Malan.Accounts.User

  describe "users" do

    @valid_attrs %{email: "some@email.com", email_verified: "2010-04-17T14:00:00Z", password: "some password", preferences: %{}, roles: [], tos_accept_time: "2010-04-17T14:00:00Z", username: "some username"}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      user
    end

    def validate_property(validation_func, key, value, valid, err_msg_regex \\ "") do
      changeset = Ecto.Changeset.cast(%User{}, %{key => value}, [key])
                  |> validation_func.()

      assert changeset.valid? == valid
      case valid do
        false -> Map.get(errors_on(changeset), key)
                 |> Enum.any?(fn (x) -> x =~ ~r/#{err_msg_regex}/ end)

        true -> true
      end
    end

    def validate_email(email, valid, err_msg_regex \\ "") do
      changeset = Ecto.Changeset.cast(%User{}, %{email: email}, [:email])
                  |> User.validate_email()

      assert changeset.valid? == valid
      case valid do
        false -> assert errors_on(changeset).email
                 |> Enum.any?(fn (x) -> x =~ ~r/#{err_msg_regex}/ end)

        true -> true
      end
    end

    test "registration_changeset" do
      assert true
    end

    test "#validate_username minimum length" do
      changeset = Ecto.Changeset.cast(%User{}, %{username: "h"}, [:username])
                  |> User.validate_username()

      assert changeset.valid? == false
      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/should be at least/ end)
    end

    test "#validate_username maximum length" do
      changeset = Ecto.Changeset.cast(%User{}, %{username: String.duplicate("A", 101)}, [:username])
                  |> User.validate_username()

      assert changeset.valid? == false
      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/should be at most/ end)
    end

    test "#validate_username only valid email prefix characters 1" do
      changeset = Ecto.Changeset.cast(%User{}, %{username: "abcdefg(h"}, [:username])
                  |> User.validate_username()

      assert changeset.valid? == false
      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/has invalid format/ end)
    end

    test "#validate_username only valid email prefix characters 2" do
      changeset = Ecto.Changeset.cast(%User{}, %{username: "abc)defgh"}, [:username])
                  |> User.validate_username()

      assert changeset.valid? == false
      assert errors_on(changeset).username
             |> Enum.any?(fn (x) -> x =~ ~r/has invalid format/ end)
    end

    test "#validate_username allows email addresses" do
      changeset = Ecto.Changeset.cast(%User{}, %{username: "hello-_=_+*&^world@example.com"}, [:username])
                  |> User.validate_username()

      assert changeset.valid? == true
    end

    test "#validate_email correct emails 1" do
      validate_email("bob@hotmail.com", true)
    end

    test "#validate_email correct emails 2" do
      validate_email("v@mx.co", true)
    end

    test "#validate_email correct emails 3" do
      validate_email("bob.zemeckis-hello+world74@hotmail.com", true)
    end

    test "#validate_email correct emails 4" do
      validate_email("bob.1!#$%^&*@hotmail.seven.four.com", true)
    end

    test "#validate_email invalid emails 1" do
      validate_email("bob@hotmail", false, "has invalid format")
    end

    test "#validate_email invalid emails 2" do
      validate_email("bob(hello@hotmail.com", false, "has invalid format")
    end

    test "#validate_email invalid emails 3" do
      validate_email("bob@hello@hotmail.com", false, "has invalid format")
    end

    test "#validate_email invalid emails 4" do
      validate_email("boblo@hot^mail.com", false, "has invalid format")
    end

    test "#validate_email invalid emails 5" do
      validate_email(
        "bob@hotmail.com#{String.duplicate("A", 25)}",
        false,
        "has invalid format"
      )
    end

    test "#validate_email max length 1" do
      validate_property(
        &User.validate_email/1,
        :email,
        "#{String.duplicate("A", 101)}@hotmail.com",
        false,
        "should be at most"
      )
    end

    test "#validate_email max length 2" do
      validate_email(
        "#{String.duplicate("A", 101)}bob@hotmail.com",
        false,
        "should be at most"
      )
    end

    test "#validate_password invalid 1" do
      validate_property(
        &User.validate_password/1,
        :password,
        "password1",
        false,
        "Should be at least"
      )
    end

    test "#validate_password valid 1" do
      validate_property(
        &User.validate_password/1,
        :password,
        "password10",
        true
      )
    end

    test "accept/reject ToS can be accepted/rejected" do
      Enum.each([true, false], fn (accept) ->
        changeset = Ecto.Changeset.cast(%User{}, %{accept_tos: accept}, [:accept_tos])
                    |> User.put_accept_tos()

        assert changeset.valid? == true
        assert changeset.valid? == true
        tos_cs = changeset.changes
                 |> Map.get(:tos_accept_events)
                 |> List.first
        assert tos_cs.valid? == true
      end)
    end

    test "accept/reject ToS if not specified takes no action" do
      changeset = Ecto.Changeset.cast(%User{}, %{accept_tos: nil}, [:accept_tos])
                  |> User.put_accept_tos()

      assert changeset.valid? == true
      assert changeset.changes == %{}
    end

    test "accept/reject ToS appends to the array" do
      changeset = Ecto.Changeset.cast(%User{}, %{accept_tos: true}, [:accept_tos])
                  |> User.put_accept_tos()

      assert changeset.valid? == true
      assert changeset.valid? == true
      tos_cs = changeset.changes
               |> Map.get(:tos_accept_events)
               |> List.first
      assert tos_cs.valid? == true
    end

    test "roles must be valid" do
      changeset = Ecto.Changeset.cast(%User{}, %{roles: ["user"]}, [:roles])
                  |> User.validate_roles()
      assert changeset.valid? == true

      changeset = Ecto.Changeset.cast(%User{}, %{roles: ["fake"]}, [:roles])
                  |> User.validate_roles()
      assert changeset.valid? == false
      assert errors_on(changeset).roles
             |> Enum.any?(fn (x) -> x =~ ~r/has an invalid entry/ end)
    end
  end

  describe "Users.Sex" do
    test "#to_s" do
      assert nil == User.Sex.to_s(nil)
      assert "Male" == User.Sex.to_s(0)
      assert "Female" == User.Sex.to_s(1)
      assert "Other" == User.Sex.to_s(2)
      assert nil == User.Sex.to_s(3)
    end

    test "#to_i" do
      assert 0 == User.Sex.to_i("Male")
      assert 1 == User.Sex.to_i("Female")
      assert 2 == User.Sex.to_i("Other")
      assert nil == User.Sex.to_i("prefer_not")
      assert nil == User.Sex.to_i("fake")
    end

    test "#valid?" do
      assert true == User.Sex.valid?("Male")
      assert true == User.Sex.valid?("Female")
      assert true == User.Sex.valid?("Other")
      assert false == User.Sex.valid?("prefer_not")
      assert false == User.Sex.valid?("fake")

      assert false == User.Sex.valid?(-1)
      assert true == User.Sex.valid?(0)
      assert true == User.Sex.valid?(1)
      assert true == User.Sex.valid?(2)
      assert false == User.Sex.valid?(3)
      assert false == User.Sex.valid?(4)
    end
  end

  describe "Users.Gender" do
    test "#to_s" do
      assert "Agender" == User.Gender.to_s(0)
      assert "Androgyne" == User.Gender.to_s(1)
      assert "Androgynes" == User.Gender.to_s(2)
      assert "Androgynous" == User.Gender.to_s(3)
      assert "Bigender" == User.Gender.to_s(4)
      assert "Cis" == User.Gender.to_s(5)
      assert "Cis Female" == User.Gender.to_s(6)
      assert "Cis Male" == User.Gender.to_s(7)
      assert "Cis Man" == User.Gender.to_s(8)
      assert "Cis Woman" == User.Gender.to_s(9)
      assert "Cisgender" == User.Gender.to_s(10)
      assert "Cisgender Female" == User.Gender.to_s(11)
      assert "Cisgender Male" == User.Gender.to_s(12)
      assert "Cisgender Man" == User.Gender.to_s(13)
      assert "Cisgender Woman" == User.Gender.to_s(14)
      assert "Female to Male" == User.Gender.to_s(15)
      assert "FTM" == User.Gender.to_s(16)
      assert "Gender Fluid" == User.Gender.to_s(17)
      assert "Gender Nonconforming" == User.Gender.to_s(18)
      assert "Gender Questioning" == User.Gender.to_s(19)
      assert "Gender Variant" == User.Gender.to_s(20)
      assert "Genderqueer" == User.Gender.to_s(21)
      assert "Intersex" == User.Gender.to_s(22)
      assert "Male to Female" == User.Gender.to_s(23)
      assert "MTF" == User.Gender.to_s(24)
      assert "Neither" == User.Gender.to_s(25)
      assert "Neutrois" == User.Gender.to_s(26)
      assert "Non-binary" == User.Gender.to_s(27)
      assert "Other" == User.Gender.to_s(28)
      assert "Pangender" == User.Gender.to_s(29)
      assert "Trans" == User.Gender.to_s(30)
      assert "Trans Female" == User.Gender.to_s(31)
      assert "Trans Male" == User.Gender.to_s(32)
      assert "Trans Man" == User.Gender.to_s(33)
      assert "Trans Person" == User.Gender.to_s(34)
      assert "Trans*Female" == User.Gender.to_s(35)
      assert "Trans*Male" == User.Gender.to_s(36)
      assert "Trans*Man" == User.Gender.to_s(37)
      assert "Trans*Person" == User.Gender.to_s(38)
      assert "Trans*Woman" == User.Gender.to_s(39)
      assert "Transexual" == User.Gender.to_s(40)
      assert "Transexual Female" == User.Gender.to_s(41)
      assert "Transexual Male" == User.Gender.to_s(42)
      assert "Transexual Man" == User.Gender.to_s(43)
      assert "Transexual Person" == User.Gender.to_s(44)
      assert "Transexual Woman" == User.Gender.to_s(45)
      assert "Transgender Female" == User.Gender.to_s(46)
      assert "Transgender Person" == User.Gender.to_s(47)
      assert "Transmasculine" == User.Gender.to_s(48)
      assert "Two-spirit" == User.Gender.to_s(49)
      assert "Male" == User.Gender.to_s(50)
      assert "Female" == User.Gender.to_s(51)
      assert nil == User.Gender.to_i("fake")
    end

    test "#to_i" do
      assert nil == User.Gender.to_i("fake")
      assert 0 == User.Gender.to_i("Agender")
      assert 1 == User.Gender.to_i("Androgyne")
      assert 2 == User.Gender.to_i("Androgynes")
      assert 3 == User.Gender.to_i("Androgynous")
      assert 4 == User.Gender.to_i("Bigender")
      assert 5 == User.Gender.to_i("Cis")
      assert 6 == User.Gender.to_i("Cis Female")
      assert 7 == User.Gender.to_i("Cis Male")
      assert 8 == User.Gender.to_i("Cis Man")
      assert 9 == User.Gender.to_i("Cis Woman")
      assert 10 == User.Gender.to_i("Cisgender")
      assert 11 == User.Gender.to_i("Cisgender Female")
      assert 12 == User.Gender.to_i("Cisgender Male")
      assert 13 == User.Gender.to_i("Cisgender Man")
      assert 14 == User.Gender.to_i("Cisgender Woman")
      assert 15 == User.Gender.to_i("Female to Male")
      assert 16 == User.Gender.to_i("FTM")
      assert 17 == User.Gender.to_i("Gender Fluid")
      assert 18 == User.Gender.to_i("Gender Nonconforming")
      assert 19 == User.Gender.to_i("Gender Questioning")
      assert 20 == User.Gender.to_i("Gender Variant")
      assert 21 == User.Gender.to_i("Genderqueer")
      assert 22 == User.Gender.to_i("Intersex")
      assert 23 == User.Gender.to_i("Male to Female")
      assert 24 == User.Gender.to_i("MTF")
      assert 25 == User.Gender.to_i("Neither")
      assert 26 == User.Gender.to_i("Neutrois")
      assert 27 == User.Gender.to_i("Non-binary")
      assert 28 == User.Gender.to_i("Other")
      assert 29 == User.Gender.to_i("Pangender")
      assert 30 == User.Gender.to_i("Trans")
      assert 31 == User.Gender.to_i("Trans Female")
      assert 32 == User.Gender.to_i("Trans Male")
      assert 33 == User.Gender.to_i("Trans Man")
      assert 34 == User.Gender.to_i("Trans Person")
      assert 35 == User.Gender.to_i("Trans*Female")
      assert 36 == User.Gender.to_i("Trans*Male")
      assert 37 == User.Gender.to_i("Trans*Man")
      assert 38 == User.Gender.to_i("Trans*Person")
      assert 39 == User.Gender.to_i("Trans*Woman")
      assert 40 == User.Gender.to_i("Transexual")
      assert 41 == User.Gender.to_i("Transexual Female")
      assert 42 == User.Gender.to_i("Transexual Male")
      assert 43 == User.Gender.to_i("Transexual Man")
      assert 44 == User.Gender.to_i("Transexual Person")
      assert 45 == User.Gender.to_i("Transexual Woman")
      assert 46 == User.Gender.to_i("Transgender Female")
      assert 47 == User.Gender.to_i("Transgender Person")
      assert 48 == User.Gender.to_i("Transmasculine")
      assert 49 == User.Gender.to_i("Two-spirit")
      assert 50 == User.Gender.to_i("Male")
      assert 51 == User.Gender.to_i("Female")
      # spot check some normalized
      assert 47 == User.Gender.to_i("transgender person")
      assert 48 == User.Gender.to_i("transmasculine")
      assert 49 == User.Gender.to_i("two-spirit")
      assert 50 == User.Gender.to_i("male")
      assert 51 == User.Gender.to_i("female")
    end

    test "#valid?" do
      assert true == User.Gender.valid?("male")
      assert true == User.Gender.valid?("female")
      assert true == User.Gender.valid?("other")
      assert false == User.Gender.valid?("fake")

      assert false == User.Gender.valid?(-1)
      assert true == User.Gender.valid?(0)
      assert true == User.Gender.valid?(1)
      assert true == User.Gender.valid?(2)
      assert true == User.Gender.valid?(3)
      assert false == User.Gender.valid?(55)
    end

    test "#normalize" do
      assert "two-spirit" == User.Gender.normalize("Two-spirit")
      assert "trans*woman" == User.Gender.normalize("Trans*Woman")
    end
  end

  describe "Users.Ethnicity" do
    test "#to_s" do
      assert nil == User.Ethnicity.to_s(nil)
      assert "Hispanic or Latinx" == User.Ethnicity.to_s(0)
      assert "Not Hispanic or Latinx" == User.Ethnicity.to_s(1)
      assert nil == User.Ethnicity.to_s(4)
    end

    test "#to_i" do
      assert 0 == User.Ethnicity.to_i("Hispanic or Latinx")
      assert 1 == User.Ethnicity.to_i("Not Hispanic or Latinx")
      assert nil == User.Ethnicity.to_i("fake")
    end

    test "#valid?" do
      assert true == User.Ethnicity.valid?("Hispanic or Latinx")
      assert true == User.Ethnicity.valid?("Not Hispanic or Latinx")
      assert false == User.Ethnicity.valid?("fake")

      assert false == User.Ethnicity.valid?(-1)
      assert true == User.Ethnicity.valid?(0)
      assert true == User.Ethnicity.valid?(1)
      assert false == User.Ethnicity.valid?(2)
    end
  end

  describe "Users.Race" do
    defp races_to_cs(races), do: %Ecto.Changeset{changes: %{race: races}}

    test "#all_races_valid?/1" do
      assert false == User.all_races_valid?(races_to_cs(["one", "two"]))
      assert true == User.all_races_valid?(races_to_cs(["Black or African American", "White"]))
      assert true == User.all_races_valid?(races_to_cs(["Asian"]))
      assert true == User.all_races_valid?(races_to_cs([
        "American Indian or Alaska Native",
        "Native Hawaiian or Other Pacific Islander"
      ]))
      assert true == User.all_races_valid?(races_to_cs([]))
      assert false == User.all_races_valid?(races_to_cs(["Asian", "one"]))
    end

    test "#race_list/1" do
      assert [1, 4] == User.race_list(races_to_cs(["Asian", "White"]))
      assert [1, 4] == User.race_list(races_to_cs(["asian", "white"]))
      assert [0, 1, 2, 3, 4] = User.race_list(races_to_cs(["American Indian or Alaska Native", "Asian", "Black or African American", "Native Hawaiian or Other Pacific Islander", "white"]))
    end
  end
end
