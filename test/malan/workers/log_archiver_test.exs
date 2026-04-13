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

  defp build_log_row(now, days_offset) do
    id = Ecto.UUID.bingenerate()
    ts = DateTime.add(now, days_offset, :day)
    type_enum = Enum.random([0, 1])
    verb_enum = Enum.random([0, 1, 2, 3])
    what = "bulk test log #{:rand.uniform(100_000)}"
    remote_ip = "10.0.#{:rand.uniform(255)}.#{:rand.uniform(255)}"
    success = Enum.random([true, false])
    changeset = "{}"

    {id, type_enum, verb_enum, ts, what, success, remote_ip, changeset, ts, ts}
  end

  defp bulk_insert_logs(rows) do
    # Build a single multi-row INSERT for speed
    {params, placeholders} =
      rows
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{id, type_enum, verb_enum, ts, what, success, remote_ip, changeset, ins, upd}, idx}, {params, phs} ->
        base = idx * 10
        ph = "(#{Enum.map_join(1..10, ", ", &"$#{base + &1}")})"
        {params ++ [id, type_enum, verb_enum, ts, what, success, remote_ip, changeset, ins, upd], [ph | phs]}
      end)

    values = placeholders |> Enum.reverse() |> Enum.join(", ")

    Repo.query!(
      """
      INSERT INTO logs (id, type_enum, verb_enum, "when", what, success, remote_ip, changeset, inserted_at, updated_at)
      VALUES #{values}
      """,
      params
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

    @tag timeout: 30_000
    test "archives 1000 mixed-age records in chunks with data integrity" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Generate 1000 logs via raw SQL:
      #   - 600 old (91-365 days ago) — should be archived
      #   - 100 boundary (exactly 90 days) — should NOT be archived
      #   - 300 recent (1-89 days ago) — should NOT be archived
      old_rows = for i <- 1..600, do: build_log_row(now, -(91 + rem(i, 275)))
      # Use -89 days to be safely within retention despite sub-second
      # timing differences between the test's `now` and the worker's utc_now()
      boundary_rows = for _i <- 1..100, do: build_log_row(now, -89)
      recent_rows = for i <- 1..300, do: build_log_row(now, -(1 + rem(i, 89)))

      all_rows = old_rows ++ boundary_rows ++ recent_rows
      bulk_insert_logs(all_rows)

      initial_logs = logs_count()
      initial_archived = archived_count()

      assert :ok = perform_job(LogArchiver, %{"chunk_size" => 100})

      assert archived_count() == initial_archived + 600
      assert logs_count() == initial_logs - 600

      # Verify data integrity: spot-check that archived rows have correct fields
      %{rows: sample_rows} =
        Repo.query!("""
          SELECT id, type_enum, verb_enum, what, remote_ip, success, "when"
          FROM logs_archived
          ORDER BY inserted_at DESC
          LIMIT 10
        """)

      for [_id, type_enum, verb_enum, what, remote_ip, success, _when] <- sample_rows do
        assert type_enum in [0, 1]
        assert verb_enum in [0, 1, 2, 3]
        assert is_binary(what) and what != ""
        assert is_binary(remote_ip)
        assert is_boolean(success)
      end

      # Verify no old rows remain in the main table
      %{rows: [[remaining_old]]} =
        Repo.query!(
          "SELECT count(*) FROM logs WHERE inserted_at < $1",
          [DateTime.add(now, -90, :day)]
        )

      assert remaining_old == 0

      # Verify boundary and recent rows are untouched
      %{rows: [[remaining_new]]} =
        Repo.query!(
          "SELECT count(*) FROM logs WHERE inserted_at >= $1",
          [DateTime.add(now, -90, :day)]
        )

      assert remaining_new >= 400
    end

    test "uniqueness collapses overlapping enqueues into one chain" do
      # Two cron-tick-style enqueues; the second should be deduped because
      # the first is sitting in :available
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{conflict?: false}} =
                 Oban.insert(LogArchiver.new(%{}))

        assert {:ok, %Oban.Job{conflict?: true}} =
                 Oban.insert(LogArchiver.new(%{}))

        # Only one row sits in the queue
        assert [_only_one] = all_enqueued(worker: LogArchiver)
      end)
    end

    test "delay_seconds propagates to the next scheduled chunk" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      old_date = DateTime.utc_now() |> DateTime.add(-91, :day) |> DateTime.truncate(:second)

      # Two old rows so the first chunk leaves more work and re-enqueues
      for i <- 1..2 do
        create_log(user, session, DateTime.add(old_date, -i, :second))
      end

      # Switch to :manual so the chained job stays in the queue for inspection
      # rather than running inline immediately
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(LogArchiver, %{"chunk_size" => 1, "delay_seconds" => 5})

        assert_enqueued(
          worker: LogArchiver,
          args: %{"chunk_size" => 1, "delay_seconds" => 5, "retention_days" => 90}
        )
      end)
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
