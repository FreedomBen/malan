defmodule Malan.Workers.LogArchiver do
  @moduledoc """
  Oban cron worker that archives audit log records older than 60 days.

  Moves rows from `logs` to `logs_archived` in configurable-size chunks
  to avoid long-running transactions and excessive lock contention.
  Keeps re-enqueueing itself until all eligible rows have been moved,
  which handles the first-run case where millions of records may need
  to be archived.
  """

  # Uniqueness keeps at most one archiver chain in flight at a time. The
  # parent chunk is in :executing while it inserts the next chunk, so
  # :executing is intentionally excluded — the chain still self-perpetuates.
  # Cron ticks that fire while a chain is already in :available or :scheduled
  # silently no-op. If a chain dies (state → :discarded), the next cron tick
  # starts a fresh one.
  use Oban.Worker,
    queue: :logs,
    max_attempts: 3,
    unique: [
      period: :infinity,
      fields: [:worker],
      states: [:available, :scheduled]
    ]

  require Logger

  alias Malan.Repo

  @default_retention_days 60
  @default_chunk_size 1_000
  # Delay between chained chunks. Zero is fine for steady-state (a daily run
  # touches a few hundred rows), but operators should set this to 1-2 seconds
  # for a multi-million-row backfill so the chain doesn't saturate the DB.
  @default_delay_seconds 0
  # Give each chunk query up to 60s. The SELECT walks an index range and the
  # DELETE+INSERT is bounded by chunk_size, so this is generous but finite.
  @query_timeout_ms 60_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days = Map.get(args, "retention_days", @default_retention_days)
    chunk_size = Map.get(args, "chunk_size", @default_chunk_size)
    delay_seconds = Map.get(args, "delay_seconds", @default_delay_seconds)
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

    case archive_chunk(cutoff, chunk_size) do
      {:ok, 0} ->
        Logger.info("LogArchiver: no more rows to archive")
        :ok

      {:ok, count} ->
        Logger.info("LogArchiver: archived #{count} rows, scheduling next chunk")
        schedule_next_chunk(retention_days, chunk_size, delay_seconds)
        :ok

      {:error, reason} ->
        Logger.error("LogArchiver: failed to archive chunk: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Single-statement move: a CTE picks the chunk, DELETE removes them with
  # RETURNING, and the outer INSERT writes them to the archive table. One
  # pass over the inserted_at index, no round-trip for an id array, and the
  # whole thing is atomic under a single implicit transaction.
  #
  # FOR UPDATE SKIP LOCKED lets overlapping runs coexist safely without
  # blocking on row locks from another archiver or a concurrent writer.
  defp archive_chunk(cutoff, chunk_size) do
    sql = """
    WITH to_archive AS (
      SELECT id FROM logs
      WHERE inserted_at < $1
      ORDER BY inserted_at ASC
      LIMIT $2
      FOR UPDATE SKIP LOCKED
    ),
    deleted AS (
      DELETE FROM logs
      WHERE id IN (SELECT id FROM to_archive)
      RETURNING id, type_enum, verb_enum, "when", what, user_id, session_id,
                who, who_username, success, changeset, remote_ip,
                inserted_at, updated_at
    )
    INSERT INTO logs_archived (
      id, type_enum, verb_enum, "when", what, user_id, session_id,
      who, who_username, success, changeset, remote_ip,
      inserted_at, updated_at
    )
    SELECT * FROM deleted
    """

    case Repo.query(sql, [cutoff, chunk_size], timeout: @query_timeout_ms) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_next_chunk(retention_days, chunk_size, delay_seconds) do
    %{
      "retention_days" => retention_days,
      "chunk_size" => chunk_size,
      "delay_seconds" => delay_seconds
    }
    |> __MODULE__.new(schedule_in: delay_seconds)
    |> Oban.insert!()
  end
end
