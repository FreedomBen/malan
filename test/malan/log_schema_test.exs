defmodule Malan.LogSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Utils
  alias Malan.Accounts.Log

  alias Malan.Test.Utils, as: TestUtils

  describe "logs" do
    test "#validate_type success" do
      changeset =
        Ecto.Changeset.cast(%Log{}, %{type: "users"}, [:type])
        |> Log.validate_type()

      assert changeset.valid? == true
      assert changeset.changes == %{type: "users", type_enum: 0}
    end

    test "#validate_type failure" do
      changeset =
        Ecto.Changeset.cast(%Log{}, %{type: "incorrect"}, [:type])
        |> Log.validate_type()

      assert changeset.valid? == false

      assert errors_on(changeset).type
             |> Enum.any?(fn x -> x =~ ~r/type is invalid/ end)
    end

    test "#validate_verb success" do
      changeset =
        Ecto.Changeset.cast(%Log{}, %{verb: "GET"}, [:verb])
        |> Log.validate_verb()

      assert changeset.valid? == true
      assert changeset.changes == %{verb: "GET", verb_enum: 0}
    end

    test "#validate_verb failure" do
      changeset =
        Ecto.Changeset.cast(%Log{}, %{verb: "incorrect"}, [:verb])
        |> Log.validate_verb()

      assert changeset.valid? == false

      assert errors_on(changeset).verb
             |> Enum.any?(fn x -> x =~ ~r/verb is invalid/ end)
    end

    test "#put_default_when sets default when not set" do
      changeset =
        Ecto.Changeset.cast(%Log{}, %{}, [:when])
        |> Log.put_default_when()

      assert changeset.valid? == true
      assert %{when: w} = changeset.changes
      assert TestUtils.DateTime.within_last?(w, 0, :seconds) == true
    end

    test "#put_default_when doesn't change if set in changes" do
      orig = Utils.DateTime.utc_now_trunc()

      changeset =
        Ecto.Changeset.cast(%Log{}, %{when: orig}, [:when])
        |> Log.put_default_when()

      assert changeset.valid? == true
      assert %{when: ^orig} = changeset.changes
    end

    test "#put_default_when doesn't get changed if already set" do
      orig = Utils.DateTime.utc_now_trunc()

      changeset =
        Ecto.Changeset.cast(%Log{when: orig}, %{}, [:when])
        |> Log.put_default_when()

      assert changeset.valid? == true
      assert changeset.changes == %{}
    end

    test "#create_changeset/2 requires type, verb, what, sets when" do
      cs = Log.create_changeset(%Log{}, %{})
      errors = errors_on(cs)
      assert Enum.all?([:type, :verb, :what], fn e -> Map.has_key?(errors, e) end)
      assert !Map.has_key?(errors, :when)
      assert TestUtils.DateTime.within_last?(cs.changes.when, 2, :seconds)
    end

    test "#create_changeset/2 allows user id to be nil" do
      cs =
        Log.create_changeset(%Log{}, %{
          success: true,
          sesson_id: "sid",
          who: Ecto.UUID.generate(),
          type: "users",
          verb: "POST",
          what: "what",
          remote_ip: "1.1.1.1"
        })

      assert cs.valid?
    end

    test "#create_changeset/2 allows session id to be nil" do
      cs =
        Log.create_changeset(%Log{}, %{
          success: false,
          user_id: "uid",
          who: Ecto.UUID.generate(),
          type: "users",
          verb: "POST",
          what: "what",
          remote_ip: "1.1.1.1"
        })

      assert cs.valid?
    end

    test "#create_changeset/2 requires who to be a binary ID" do
      cs =
        Log.create_changeset(%Log{}, %{
          success: true,
          user_id: "uid",
          who: Ecto.UUID.generate(),
          type: "users",
          verb: "POST",
          what: "what",
          remote_ip: "1.1.1.1"
        })

      assert cs.valid?
    end
  end

  describe "Log.Type" do
    test "#to_s" do
      assert nil == Log.Type.to_s(nil)
      assert "users" == Log.Type.to_s(0)
      assert "sessions" == Log.Type.to_s(1)
      assert nil == Log.Type.to_s(2)
    end

    test "#to_i" do
      assert 0 == Log.Type.to_i("users")
      assert 1 == Log.Type.to_i("sessions")
      assert nil == Log.Type.to_i("prefer_not")
      assert nil == Log.Type.to_i("fake")
      # check normalization
      assert 0 == Log.Type.to_i("Users")
      assert 0 == Log.Type.to_i("USERS")
      assert 1 == Log.Type.to_i("sessIONS")
      assert 1 == Log.Type.to_i("sessions")
    end

    test "#valid?" do
      assert true == Log.Type.valid?("users")
      assert true == Log.Type.valid?("sessions")
      assert false == Log.Type.valid?("prefer_not")
      assert false == Log.Type.valid?("fake")

      assert false == Log.Type.valid?(-1)
      assert true == Log.Type.valid?(0)
      assert true == Log.Type.valid?(1)
      assert false == Log.Type.valid?(2)
      assert false == Log.Type.valid?(3)
    end

    test "#normalize" do
      assert "users" == Log.Type.normalize("UserS")
      assert "sessions" == Log.Type.normalize("SessIOns")
    end
  end

  describe "Log.Verb" do
    test "#to_s" do
      assert "GET" == Log.Verb.to_s(0)
      assert "POST" == Log.Verb.to_s(1)
      assert "PUT" == Log.Verb.to_s(2)
      assert "DELETE" == Log.Verb.to_s(3)
      assert nil == Log.Verb.to_s(51)
      assert nil == Log.Verb.to_i("fake")
    end

    test "#to_i" do
      assert nil == Log.Verb.to_i("fake")
      assert 0 == Log.Verb.to_i("GET")
      assert 1 == Log.Verb.to_i("POST")
      assert 2 == Log.Verb.to_i("PUT")
      assert 3 == Log.Verb.to_i("DELETE")
      # check normalization
      assert 0 == Log.Verb.to_i("get")
      assert 1 == Log.Verb.to_i("post")
      assert 2 == Log.Verb.to_i("put")
      assert 3 == Log.Verb.to_i("delete")
    end

    test "#valid?" do
      assert true == Log.Verb.valid?("GET")
      assert true == Log.Verb.valid?("POST")
      assert true == Log.Verb.valid?("PUT")
      assert true == Log.Verb.valid?("DELETE")
      assert false == Log.Verb.valid?("fake")

      assert false == Log.Verb.valid?(-1)
      assert true == Log.Verb.valid?(0)
      assert true == Log.Verb.valid?(1)
      assert true == Log.Verb.valid?(2)
      assert true == Log.Verb.valid?(3)
      assert false == Log.Verb.valid?(4)
    end

    test "#normalize" do
      assert "GET" == Log.Verb.normalize("get")
      assert "POST" == Log.Verb.normalize("poST")
    end
  end
end
