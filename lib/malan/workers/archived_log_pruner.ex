defmodule Malan.Workers.ArchivedLogPruner do
  @moduledoc """
  Oban cron worker that deletes archived audit log records older than two
  years (730 days).

  `logs_archived` rows keep the `inserted_at` of the original `logs` row
  (see `Malan.Workers.LogArchiver`), so the cutoff is measured from when a
  log was first written: ~60 days in `logs`, the remainder in
  `logs_archived`, two years of retention total.

  Deletes in configurable-size chunks to avoid long-running transactions and
  excessive lock contention. Re-enqueues itself until all eligible rows are
  gone or the per-run chunk cap (`max_chunks`) is reached, whichever comes
  first. Deletion is permanent — rows are not exported anywhere first — so a
  retention floor (`@min_retention_days`) rejects suspiciously short
  `retention_days` args instead of quietly gutting the archive.
  """

  # Shares the single-worker :archive queue with LogArchiver so the two
  # maintenance jobs serialize instead of contending, and neither can occupy
  # the worker slots the request-path :logs queue needs.
  #
  # Uniqueness keeps at most one pruner chain in flight at a time. The fields
  # are scoped to [:worker], so the pruner and archiver chains never dedupe
  # each other. See LogArchiver for the full rationale on the excluded
  # :executing state and how max_chunks bounds run length.
  use Oban.Worker,
    queue: :archive,
    max_attempts: 3,
    unique: [
      period: :infinity,
      fields: [:worker],
      states: [:available, :scheduled]
    ]

  require Logger

  alias Malan.Repo

  # Two years, measured against the original log's inserted_at.
  @default_retention_days 730
  # Deletes are irreversible, so refuse clearly-wrong retention windows
  # (e.g. a fat-fingered 73 instead of 730) rather than run with them.
  @min_retention_days 365
  @default_chunk_size 1_000
  # See LogArchiver: zero is fine at steady state; operators should set 1-2s
  # when clearing a multi-million-row backlog so the chain doesn't saturate
  # the DB.
  @default_delay_seconds 0
  @default_max_chunks 500
  @query_timeout_ms 60_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days = Map.get(args, "retention_days", @default_retention_days)

    if is_integer(retention_days) and retention_days >= @min_retention_days do
      prune(args, retention_days)
    else
      Logger.error(
        "ArchivedLogPruner: refusing to run with retention_days=#{inspect(retention_days)}; must be an integer >= #{@min_retention_days} because deleted rows are unrecoverable"
      )

      {:error, :invalid_retention_days}
    end
  end

  defp prune(args, retention_days) do
    chunk_size = Map.get(args, "chunk_size", @default_chunk_size)
    delay_seconds = Map.get(args, "delay_seconds", @default_delay_seconds)
    chunk = Map.get(args, "chunk", 1)
    max_chunks = Map.get(args, "max_chunks", @default_max_chunks)
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

    case delete_chunk(cutoff, chunk_size) do
      {:ok, 0} ->
        Logger.info("ArchivedLogPruner: no more rows to prune")
        :ok

      {:ok, count} when chunk >= max_chunks ->
        Logger.info(
          "ArchivedLogPruner: deleted #{count} rows, hit max_chunks=#{max_chunks} for this run; remaining rows (if any) will be pruned on the next scheduled run"
        )

        :ok

      {:ok, count} ->
        Logger.info(
          "ArchivedLogPruner: deleted #{count} rows (chunk #{chunk}/#{max_chunks}), scheduling next chunk"
        )

        schedule_next_chunk(retention_days, chunk_size, delay_seconds, chunk + 1, max_chunks)
        :ok

      {:error, reason} ->
        Logger.error("ArchivedLogPruner: failed to delete chunk: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Unlike LogArchiver's chunk SELECT, no ORDER BY: logs_archived only has a
  # BRIN index on inserted_at (the btrees were dropped as write
  # amplification), so an ordered LIMIT would bitmap-scan and sort the entire
  # qualifying backlog on every chunk. Unordered, the scan can stop at
  # chunk_size matches, and deletion order doesn't matter for retention.
  #
  # FOR UPDATE SKIP LOCKED lets an overlapping run coexist safely instead of
  # blocking on another pruner's row locks.
  defp delete_chunk(cutoff, chunk_size) do
    sql = """
    WITH to_delete AS (
      SELECT id FROM logs_archived
      WHERE inserted_at < $1
      LIMIT $2
      FOR UPDATE SKIP LOCKED
    )
    DELETE FROM logs_archived
    WHERE id IN (SELECT id FROM to_delete)
    """

    case Repo.query(sql, [cutoff, chunk_size], timeout: @query_timeout_ms) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_next_chunk(retention_days, chunk_size, delay_seconds, chunk, max_chunks) do
    %{
      "retention_days" => retention_days,
      "chunk_size" => chunk_size,
      "delay_seconds" => delay_seconds,
      "chunk" => chunk,
      "max_chunks" => max_chunks
    }
    |> __MODULE__.new(schedule_in: delay_seconds)
    |> Oban.insert!()
  end
end
