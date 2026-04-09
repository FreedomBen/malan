defmodule Malan.Workers.LogArchiverTest do
  use Malan.DataCase, async: false
  use Oban.Testing, repo: Malan.Repo

  alias Malan.Repo
  alias Malan.Test.Helpers
  alias Malan.Workers.LogArchiver

  defp create_log(user, session, inserted_at) do
    args = %{
      "success" => true,
      "user_id" => user.id,
      "session_id" => session.id,
      "who" => user.id,
      "who_username" => user.username,
      "type" => "users",
      "verb" => "GET",
      "what" => "archiver test log",
      "remote_ip" => "10.0.0.1",
      "changeset" => %{},
      "when" => inserted_at |> DateTime.to_iso8601()
    }

    assert :ok = perform_job(Malan.Workers.LogWriter, args)

    # Backdate the inserted_at to simulate an old record
    {:ok, who_bin} = Ecto.UUID.dump(user.id)

    Repo.query!(
      "UPDATE logs SET inserted_at = $1 WHERE who = $2 AND inserted_at > $3",
      [inserted_at, who_bin, inserted_at]
    )
  end

  defp archived_count do
    Repo.query!("SELECT count(*) FROM logs_archived").rows |> hd() |> hd()
  end

  defp logs_count do
    Repo.query!("SELECT count(*) FROM logs").rows |> hd() |> hd()
  end

  describe "perform/1" do
    test "archives logs older than 90 days" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      old_date = DateTime.utc_now() |> DateTime.add(-91, :day) |> DateTime.truncate(:second)

      initial_logs = logs_count()
      create_log(user, session, old_date)
      assert logs_count() == initial_logs + 1

      assert :ok = perform_job(LogArchiver, %{})

      assert archived_count() >= 1
      assert logs_count() == initial_logs
    end

    test "does not archive logs newer than 90 days" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      recent_date = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second)

      initial_logs = logs_count()
      initial_archived = archived_count()
      create_log(user, session, recent_date)

      assert :ok = perform_job(LogArchiver, %{})

      assert logs_count() == initial_logs + 1
      assert archived_count() == initial_archived
    end

    test "respects custom retention_days" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      date_45_days_ago = DateTime.utc_now() |> DateTime.add(-45, :day) |> DateTime.truncate(:second)

      initial_logs = logs_count()
      create_log(user, session, date_45_days_ago)

      # With default 90 days, this should NOT be archived
      assert :ok = perform_job(LogArchiver, %{})
      assert logs_count() == initial_logs + 1

      # With 30-day retention, it SHOULD be archived
      assert :ok = perform_job(LogArchiver, %{"retention_days" => 30})
      assert logs_count() == initial_logs
    end

    test "processes in chunks and archives all eligible rows" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      old_date = DateTime.utc_now() |> DateTime.add(-91, :day) |> DateTime.truncate(:second)

      # Create 3 old logs
      for i <- 1..3 do
        adjusted_date = DateTime.add(old_date, -i, :second)
        create_log(user, session, adjusted_date)
      end

      initial_archived = archived_count()
      initial_logs = logs_count()

      # Archive with chunk_size of 2 — in inline test mode, follow-up jobs
      # run immediately, so all 3 rows get archived across 2 chunks
      assert :ok = perform_job(LogArchiver, %{"chunk_size" => 2})
      assert archived_count() == initial_archived + 3
      assert logs_count() == initial_logs - 3
    end

    test "no-ops when there are no rows to archive" do
      initial_archived = archived_count()
      initial_logs = logs_count()

      assert :ok = perform_job(LogArchiver, %{})

      assert archived_count() == initial_archived
      assert logs_count() == initial_logs
      refute_enqueued(worker: LogArchiver)
    end
  end
end
