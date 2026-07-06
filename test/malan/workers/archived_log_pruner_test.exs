defmodule Malan.Workers.ArchivedLogPrunerTest do
  use Malan.DataCase, async: false
  use Oban.Testing, repo: Malan.Repo

  alias Malan.Repo
  alias Malan.Test.Helpers
  alias Malan.Workers.ArchivedLogPruner
  alias Malan.Workers.LogArchiver

  defp build_archived_row(now, days_offset) do
    id = Ecto.UUID.bingenerate()
    ts = DateTime.add(now, days_offset, :day)
    type_enum = Enum.random([0, 1])
    verb_enum = Enum.random([0, 1, 2, 3])
    what = "pruner test log #{:rand.uniform(100_000)}"
    remote_ip = "10.0.#{:rand.uniform(255)}.#{:rand.uniform(255)}"
    success = Enum.random([true, false])
    changeset = "{}"

    {id, type_enum, verb_enum, ts, what, success, remote_ip, changeset, ts, ts}
  end

  defp bulk_insert_archived(rows) do
    # Build a single multi-row INSERT for speed
    {params, placeholders} =
      rows
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{id, type_enum, verb_enum, ts, what, success, remote_ip,
                                    changeset, ins, upd}, idx},
                                  {params, phs} ->
        base = idx * 10
        ph = "(#{Enum.map_join(1..10, ", ", &"$#{base + &1}")})"

        {params ++ [id, type_enum, verb_enum, ts, what, success, remote_ip, changeset, ins, upd],
         [ph | phs]}
      end)

    values = placeholders |> Enum.reverse() |> Enum.join(", ")

    Repo.query!(
      """
      INSERT INTO logs_archived (id, type_enum, verb_enum, "when", what, success, remote_ip, changeset, inserted_at, updated_at)
      VALUES #{values}
      """,
      params
    )
  end

  defp insert_archived_log(now, days_offset) do
    bulk_insert_archived([build_archived_row(now, days_offset)])
  end

  defp create_log(user, session, inserted_at) do
    args = %{
      "success" => true,
      "user_id" => user.id,
      "session_id" => session.id,
      "who" => user.id,
      "who_username" => user.username,
      "type" => "users",
      "verb" => "GET",
      "what" => "pruner lifecycle test log",
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

  defp pruner_crontab_entry do
    Application.fetch_env!(:malan, Oban)
    |> Keyword.fetch!(:plugins)
    |> Enum.find_value(fn
      {Oban.Plugins.Cron, cron_opts} ->
        cron_opts
        |> Keyword.get(:crontab, [])
        |> Enum.find(&(elem(&1, 1) == ArchivedLogPruner))

      _ ->
        nil
    end)
  end

  describe "cron configuration" do
    test "pruner is scheduled daily off-peak, after the archiver's run" do
      entry = pruner_crontab_entry()
      assert entry, "ArchivedLogPruner must have a cron entry"

      schedule = elem(entry, 0)
      assert schedule == "45 7 * * *"
      refute schedule == "0 * * * *"
    end

    test "pruner cron throttles with smaller chunks and an inter-chunk delay" do
      entry = pruner_crontab_entry()
      assert tuple_size(entry) == 3, "expected the cron entry to carry throttle args"

      args = entry |> elem(2) |> Keyword.fetch!(:args)
      assert args["chunk_size"] == 250
      assert args["delay_seconds"] == 2
    end
  end

  describe "queue configuration" do
    test "pruner shares the :archive queue, isolated from the request-path :logs queue" do
      assert Ecto.Changeset.get_field(ArchivedLogPruner.new(%{}), :queue) == "archive"

      queues = Application.fetch_env!(:malan, Oban) |> Keyword.fetch!(:queues)
      assert queues[:archive] >= 1, "the :archive queue must be configured to run"
      assert Keyword.has_key?(queues, :logs), "the request-path :logs queue still exists"
    end
  end

  describe "perform/1" do
    test "deletes archived rows older than two years without touching the logs table" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      initial_archived = archived_count()
      initial_logs = logs_count()
      insert_archived_log(now, -731)
      assert archived_count() == initial_archived + 1

      assert :ok = perform_job(ArchivedLogPruner, %{})

      assert archived_count() == initial_archived
      assert logs_count() == initial_logs
    end

    test "retains archived rows newer than two years" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      initial_archived = archived_count()
      insert_archived_log(now, -700)
      insert_archived_log(now, -61)

      assert :ok = perform_job(ArchivedLogPruner, %{})

      assert archived_count() == initial_archived + 2
    end

    test "respects custom retention_days" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      initial_archived = archived_count()
      insert_archived_log(now, -400)

      # With the default 730 days, this should NOT be deleted
      assert :ok = perform_job(ArchivedLogPruner, %{})
      assert archived_count() == initial_archived + 1

      # With 365-day retention, it SHOULD be deleted
      assert :ok = perform_job(ArchivedLogPruner, %{"retention_days" => 365})
      assert archived_count() == initial_archived
    end

    test "refuses retention windows below the safety floor" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      initial_archived = archived_count()
      insert_archived_log(now, -731)

      # A fat-fingered short window must fail loudly and delete nothing
      assert {:error, :invalid_retention_days} =
               perform_job(ArchivedLogPruner, %{"retention_days" => 73})

      # Same for a non-integer value
      assert {:error, :invalid_retention_days} =
               perform_job(ArchivedLogPruner, %{"retention_days" => "730"})

      assert archived_count() == initial_archived + 1
      refute_enqueued(worker: ArchivedLogPruner)
    end

    test "processes in chunks and deletes all eligible rows" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      initial_archived = archived_count()

      # Create 3 expired rows
      for i <- 1..3 do
        insert_archived_log(now, -(731 + i))
      end

      # Delete with chunk_size of 2 — in inline test mode, follow-up jobs
      # run immediately, so all 3 rows get deleted across 2 chunks
      assert :ok = perform_job(ArchivedLogPruner, %{"chunk_size" => 2})
      assert archived_count() == initial_archived
    end

    @tag timeout: 30_000
    test "deletes 1000 mixed-age records in chunks, retaining everything in the window" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Generate 1000 archived logs via raw SQL:
      #   - 600 expired (731-1005 days ago) — should be deleted
      #   - 100 boundary (729 days ago, safely within retention despite
      #     sub-second timing differences with the worker's utc_now()) — kept
      #   - 300 recent (1-700 days ago) — kept
      expired_rows = for i <- 1..600, do: build_archived_row(now, -(731 + rem(i, 275)))
      boundary_rows = for _i <- 1..100, do: build_archived_row(now, -729)
      recent_rows = for i <- 1..300, do: build_archived_row(now, -(1 + rem(i, 700)))

      all_rows = expired_rows ++ boundary_rows ++ recent_rows
      bulk_insert_archived(all_rows)

      initial_archived = archived_count()

      assert :ok = perform_job(ArchivedLogPruner, %{"chunk_size" => 100})

      assert archived_count() == initial_archived - 600

      # Verify no expired rows remain in the archive
      %{rows: [[remaining_expired]]} =
        Repo.query!(
          "SELECT count(*) FROM logs_archived WHERE inserted_at < $1",
          [DateTime.add(now, -730, :day)]
        )

      assert remaining_expired == 0

      # Verify boundary and recent rows are untouched
      %{rows: [[remaining_kept]]} =
        Repo.query!(
          "SELECT count(*) FROM logs_archived WHERE inserted_at >= $1",
          [DateTime.add(now, -730, :day)]
        )

      assert remaining_kept >= 400
    end

    test "uniqueness collapses overlapping enqueues into one chain" do
      # Two cron-tick-style enqueues; the second should be deduped because
      # the first is sitting in :available
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{conflict?: false}} =
                 Oban.insert(ArchivedLogPruner.new(%{}))

        assert {:ok, %Oban.Job{conflict?: true}} =
                 Oban.insert(ArchivedLogPruner.new(%{}))

        # Only one row sits in the queue
        assert [_only_one] = all_enqueued(worker: ArchivedLogPruner)
      end)
    end

    test "pruner and archiver chains do not dedupe each other" do
      # Uniqueness is scoped to [:worker]; a queued archiver must not
      # swallow the pruner's enqueue (or vice versa)
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{conflict?: false}} = Oban.insert(LogArchiver.new(%{}))
        assert {:ok, %Oban.Job{conflict?: false}} = Oban.insert(ArchivedLogPruner.new(%{}))

        assert [_archiver] = all_enqueued(worker: LogArchiver)
        assert [_pruner] = all_enqueued(worker: ArchivedLogPruner)
      end)
    end

    test "delay_seconds propagates to the next scheduled chunk" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Two expired rows so the first chunk leaves more work and re-enqueues
      for i <- 1..2 do
        insert_archived_log(now, -(731 + i))
      end

      # Switch to :manual so the chained job stays in the queue for inspection
      # rather than running inline immediately
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(ArchivedLogPruner, %{"chunk_size" => 1, "delay_seconds" => 5})

        assert_enqueued(
          worker: ArchivedLogPruner,
          args: %{"chunk_size" => 1, "delay_seconds" => 5, "retention_days" => 730}
        )
      end)
    end

    test "no-ops when there are no rows to prune" do
      initial_archived = archived_count()

      assert :ok = perform_job(ArchivedLogPruner, %{})

      assert archived_count() == initial_archived
      refute_enqueued(worker: ArchivedLogPruner)
    end

    test "stops after max_chunks, leaving remaining rows for the next run" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Five expired rows; cap the run at two chunks of one row each.
      for i <- 1..5 do
        insert_archived_log(now, -(731 + i))
      end

      initial_archived = archived_count()

      # Inline mode would run the chain to completion, but the cap stops it at 2.
      assert :ok = perform_job(ArchivedLogPruner, %{"chunk_size" => 1, "max_chunks" => 2})

      assert archived_count() == initial_archived - 2
    end

    test "threads the chunk counter and max_chunks to the next scheduled chunk" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for i <- 1..2 do
        insert_archived_log(now, -(731 + i))
      end

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(ArchivedLogPruner, %{"chunk_size" => 1, "max_chunks" => 10})

        assert_enqueued(
          worker: ArchivedLogPruner,
          args: %{"chunk" => 2, "max_chunks" => 10, "chunk_size" => 1}
        )
      end)
    end

    test "full lifecycle: a log is archived at 60 days and pruned at two years" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      expired_date = DateTime.add(now, -800, :day)
      archived_date = DateTime.add(now, -100, :day)

      initial_logs = logs_count()
      initial_archived = archived_count()

      create_log(user, session, expired_date)
      create_log(user, session, archived_date)

      # The archiver moves both out of the live table...
      assert :ok = perform_job(LogArchiver, %{})
      assert logs_count() == initial_logs
      assert archived_count() == initial_archived + 2

      # ...and the pruner deletes only the one past two years
      assert :ok = perform_job(ArchivedLogPruner, %{})
      assert archived_count() == initial_archived + 1

      %{rows: [[remaining]]} =
        Repo.query!("SELECT count(*) FROM logs_archived WHERE what = 'pruner lifecycle test log'")

      assert remaining == 1
    end
  end
end
