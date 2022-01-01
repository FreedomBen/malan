defmodule Malan.TransactionSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Utils
  alias Malan.Accounts.User
  alias Malan.Accounts.Transaction

  alias Malan.Test.Utils, as: TestUtils

  describe "transactions" do

    def validate_property(validation_func, key, value, valid, err_msg_regex \\ "") do
      changeset =
        Ecto.Changeset.cast(%User{}, %{key => value}, [key])
        |> validation_func.()

      assert changeset.valid? == valid

      case valid do
        false ->
          Map.get(errors_on(changeset), key)
          |> Enum.any?(fn x -> x =~ ~r/#{err_msg_regex}/ end)

        true ->
          true
      end
    end

    def validate_email(email, valid, err_msg_regex \\ "") do
      changeset =
        Ecto.Changeset.cast(%User{}, %{email: email}, [:email])
        |> User.validate_email()

      assert changeset.valid? == valid

      case valid do
        false ->
          assert errors_on(changeset).email
                 |> Enum.any?(fn x -> x =~ ~r/#{err_msg_regex}/ end)

        true ->
          true
      end
    end

    test "#validate_type success" do
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{type: "users"}, [:type])
        |> Transaction.validate_type()

      assert changeset.valid? == true
      assert changeset.changes == %{type: "users", type_enum: 0}
    end

    test "#validate_type failure" do
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{type: "incorrect"}, [:type])
        |> Transaction.validate_type()

      assert changeset.valid? == false

      assert errors_on(changeset).type
             |> Enum.any?(fn x -> x =~ ~r/type is invalid/ end)
    end

    test "#validate_verb success" do
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{verb: "GET"}, [:verb])
        |> Transaction.validate_verb()

      assert changeset.valid? == true
      assert changeset.changes == %{verb: "GET", verb_enum: 0}
    end

    test "#validate_verb failure" do
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{verb: "incorrect"}, [:verb])
        |> Transaction.validate_verb()

      assert changeset.valid? == false

      assert errors_on(changeset).verb
             |> Enum.any?(fn x -> x =~ ~r/verb is invalid/ end)
    end

    test "#put_default_when sets default when not set" do
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{}, [:when])
        |> Transaction.put_default_when()

      assert changeset.valid? == true
      assert %{when: w} = changeset.changes
      assert TestUtils.DateTime.within_last?(w, 0, :seconds) == true
    end

    test "#put_default_when doesn't change if set in changes" do
      orig = Utils.DateTime.utc_now_trunc()
      changeset =
        Ecto.Changeset.cast(%Transaction{}, %{when: orig}, [:when])
        |> Transaction.put_default_when()

      assert changeset.valid? == true
      assert %{when: ^orig} = changeset.changes
    end

    test "#put_default_when doesn't get changed if already set" do
      orig = Utils.DateTime.utc_now_trunc()
      changeset =
        Ecto.Changeset.cast(%Transaction{when: orig}, %{}, [:when])
        |> Transaction.put_default_when()

      assert changeset.valid? == true
      assert changeset.changes == %{}
    end

    test "#create_changeset/2 requires who, type, verb, what, sets when" do
      cs = Transaction.create_changeset(%Transaction{}, %{})
      errors = errors_on(cs)
      assert Enum.all?([:who, :type, :verb, :what], fn e -> Map.has_key?(errors, e) end)
      assert !Map.has_key?(errors, :when)
      assert TestUtils.DateTime.within_last?(cs.changes.when, 2, :seconds)
    end

    test "#create_changeset/2 allows user id to be nil" do
      cs = Transaction.create_changeset(%Transaction{}, %{})
    end

    test "#create_changeset/2 allows session id to be nil" do
      cs = Transaction.create_changeset(%Transaction{}, %{})
    end

    test "#create_changeset/2 requires who to point to a real user ID" do
      cs = Transaction.create_changeset(%Transaction{who: Ecto.UUID.generate()}, %{})
    end


    test "#validate_username allows email addresses" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{username: "hello-_=_+*&^world@example.com"}, [:username])
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

    test "#validate_password invalid 1 because too short" do
      validate_property(
        &User.validate_password/1,
        :password,
        # "password1",
        "pass",
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
  end

  describe "Transaction.Type" do
    test "#to_s" do
      assert nil == Transaction.Type.to_s(nil)
      assert "users" == Transaction.Type.to_s(0)
      assert "sessions" == Transaction.Type.to_s(1)
      assert nil == Transaction.Type.to_s(2)
    end

    test "#to_i" do
      assert 0 == Transaction.Type.to_i("users")
      assert 1 == Transaction.Type.to_i("sessions")
      assert nil == Transaction.Type.to_i("prefer_not")
      assert nil == Transaction.Type.to_i("fake")
      # check normalization
      assert 0 == Transaction.Type.to_i("Users")
      assert 0 == Transaction.Type.to_i("USERS")
      assert 1 == Transaction.Type.to_i("sessIONS")
      assert 1 == Transaction.Type.to_i("sessions")
    end

    test "#valid?" do
      assert true == Transaction.Type.valid?("users")
      assert true == Transaction.Type.valid?("sessions")
      assert false == Transaction.Type.valid?("prefer_not")
      assert false == Transaction.Type.valid?("fake")

      assert false == Transaction.Type.valid?(-1)
      assert true == Transaction.Type.valid?(0)
      assert true == Transaction.Type.valid?(1)
      assert false == Transaction.Type.valid?(2)
      assert false == Transaction.Type.valid?(3)
    end

    test "#normalize" do
      assert "users" == Transaction.Type.normalize("UserS")
      assert "sessions" == Transaction.Type.normalize("SessIOns")
    end
  end

  describe "Transaction.Verb" do
    test "#to_s" do
      assert "GET" == Transaction.Verb.to_s(0)
      assert "POST" == Transaction.Verb.to_s(1)
      assert "PUT" == Transaction.Verb.to_s(2)
      assert "DELETE" == Transaction.Verb.to_s(3)
      assert nil == Transaction.Verb.to_s(51)
      assert nil == Transaction.Verb.to_i("fake")
    end

    test "#to_i" do
      assert nil == Transaction.Verb.to_i("fake")
      assert 0 == Transaction.Verb.to_i("GET")
      assert 1 == Transaction.Verb.to_i("POST")
      assert 2 == Transaction.Verb.to_i("PUT")
      assert 3 == Transaction.Verb.to_i("DELETE")
      # check normalization
      assert 0 == Transaction.Verb.to_i("get")
      assert 1 == Transaction.Verb.to_i("post")
      assert 2 == Transaction.Verb.to_i("put")
      assert 3 == Transaction.Verb.to_i("delete")
    end

    test "#valid?" do
      assert true == Transaction.Verb.valid?("GET")
      assert true == Transaction.Verb.valid?("POST")
      assert true == Transaction.Verb.valid?("PUT")
      assert true == Transaction.Verb.valid?("DELETE")
      assert false == Transaction.Verb.valid?("fake")

      assert false == Transaction.Verb.valid?(-1)
      assert true == Transaction.Verb.valid?(0)
      assert true == Transaction.Verb.valid?(1)
      assert true == Transaction.Verb.valid?(2)
      assert true == Transaction.Verb.valid?(3)
      assert false == Transaction.Verb.valid?(4)
    end

    test "#normalize" do
      assert "GET" == Transaction.Verb.normalize("get")
      assert "POST" == Transaction.Verb.normalize("poST")
    end
  end
end
