defmodule Malan.Workers.LogWriterTest do
  use Malan.DataCase, async: true
  use Oban.Testing, repo: Malan.Repo

  alias Malan.Accounts
  alias Malan.Accounts.Log
  alias Malan.Accounts.User
  alias Malan.Test.Helpers
  alias Malan.Workers.LogWriter

  describe "perform/1" do
    test "inserts a log record with valid args" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      args = %{
        "success" => true,
        "user_id" => user.id,
        "session_id" => session.id,
        "who" => user.id,
        "who_username" => user.username,
        "type" => "users",
        "verb" => "GET",
        "what" => "LogWriter test",
        "remote_ip" => "10.0.0.1",
        "changeset" => %{},
        "when" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
      }

      assert :ok = perform_job(LogWriter, args)

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "LogWriter test"
      assert log.success == true
      assert log.type_enum == Log.Type.to_i("users")
      assert log.verb_enum == Log.Verb.to_i("GET")
      assert log.remote_ip == "10.0.0.1"
      assert log.user_id == user.id
      assert log.session_id == session.id
      assert log.who == user.id
      assert log.who_username == user.username
    end

    test "returns error for invalid args" do
      args = %{
        "success" => nil,
        "user_id" => nil,
        "session_id" => nil,
        "who" => nil,
        "who_username" => nil,
        "type" => nil,
        "verb" => nil,
        "what" => nil,
        "remote_ip" => nil,
        "changeset" => %{}
      }

      assert {:error, _reason} = perform_job(LogWriter, args)
    end

    test "preserves changeset data through JSON round-trip" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      changeset_data = %{
        "errors" => ["some error"],
        "changes" => %{"username" => "newname"},
        "data" => %{"username" => "oldname"},
        "data_type" => "users",
        "action" => "update",
        "valid?" => true
      }

      args = %{
        "success" => true,
        "user_id" => user.id,
        "session_id" => session.id,
        "who" => user.id,
        "who_username" => user.username,
        "type" => "users",
        "verb" => "PUT",
        "what" => "changeset test",
        "remote_ip" => "10.0.0.1",
        "changeset" => changeset_data,
        "when" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
      }

      assert :ok = perform_job(LogWriter, args)

      log = Accounts.get_log_by!(who: user.id)
      assert log.changeset.action == "update"
      assert log.changeset.valid? == true
      assert log.changeset.errors == ["some error"]
      assert log.changeset.changes == %{"username" => "newname"}
    end
  end

  describe "record_log/10 integration" do
    test "enqueues a job that writes a log to the database" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      assert {:ok, _job} =
               Accounts.record_log(
                 true,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "users",
                 "POST",
                 "record_log integration test",
                 "192.168.1.1",
                 %{}
               )

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "record_log integration test"
      assert log.success == true
      assert log.remote_ip == "192.168.1.1"
    end

    test "properly serializes an Ecto changeset" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      ecto_changeset = User.registration_changeset(%User{}, %{
        "username" => "testuser_cs",
        "email" => "testuser_cs@example.com",
        "password" => "supersecretpassword123"
      })

      assert {:ok, _job} =
               Accounts.record_log(
                 true,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "users",
                 "POST",
                 "ecto changeset serialization test",
                 "10.0.0.1",
                 ecto_changeset
               )

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "ecto changeset serialization test"
      assert log.changeset.data_type == "users"
      # Password should be masked by Changes.map_from_changeset
      assert log.changeset.changes["password"] =~ ~r/^\*+$/
    end

    test "handles a plain map changeset" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      assert {:ok, _job} =
               Accounts.record_log(
                 false,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "sessions",
                 "DELETE",
                 "plain map changeset test",
                 "172.16.0.1",
                 %{}
               )

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "plain map changeset test"
      assert log.success == false
      assert log.verb_enum == Log.Verb.to_i("DELETE")
      assert log.type_enum == Log.Type.to_i("sessions")
    end

    test "captures the when timestamp at enqueue time" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, _job} =
               Accounts.record_log(
                 true,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "users",
                 "GET",
                 "timestamp test",
                 "10.0.0.1",
                 %{}
               )

      log = Accounts.get_log_by!(who: user.id)
      assert DateTime.compare(log.when, before) in [:eq, :gt]
      assert DateTime.compare(log.when, DateTime.utc_now()) in [:eq, :lt]
    end

    test "handles nil user_id and session_id for unauthenticated actions" do
      {:ok, user, _session} = Helpers.Accounts.regular_user_with_session()

      assert {:ok, _job} =
               Accounts.record_log(
                 false,
                 nil,
                 nil,
                 user.id,
                 user.username,
                 "sessions",
                 "POST",
                 "failed login attempt",
                 "203.0.113.1",
                 %{}
               )

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "failed login attempt"
      assert log.user_id == nil
      assert log.session_id == nil
      assert log.success == false
    end

    test "serializes changeset with nested embedded schemas" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      # Create a changeset that includes embedded Preference struct in its data,
      # similar to what happens during user update operations
      user_with_prefs = %{user | preferences: %Malan.Accounts.Preference{
        theme: "dark",
        display_name_pref: "nick_name",
        display_middle_initial_only: true
      }}

      ecto_changeset = Ecto.Changeset.change(user_with_prefs, %{nick_name: "Tester"})

      assert {:ok, _job} =
               Accounts.record_log(
                 true,
                 user.id,
                 session.id,
                 user.id,
                 user.username,
                 "users",
                 "PUT",
                 "nested struct serialization test",
                 "10.0.0.1",
                 ecto_changeset
               )

      log = Accounts.get_log_by!(who: user.id)
      assert log.what == "nested struct serialization test"
      assert log.changeset.data_type == "users"
    end
  end
end
