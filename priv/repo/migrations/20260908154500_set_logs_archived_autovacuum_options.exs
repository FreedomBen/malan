defmodule Malan.Repo.Migrations.SetLogsArchivedAutovacuumOptions do
  use Ecto.Migration

  # logs_archived is too large for the default autovacuum trigger to ever
  # fire: at ~13M rows, autovacuum_vacuum_scale_factor 0.2 requires ~2.6M
  # recorded dead tuples, while the ArchivedLogPruner produces only ~20K/day
  # (and the counters reset to zero on every failover/restart). In prod the
  # table went months with autovacuum_count = 0, so the pruner's chunk scans
  # waded through an ever-growing region of unreclaimed dead tuples until
  # they exceeded the worker's 60s query timeout (Sentry MALAN-F5..MALAN-F9).
  #
  # Fixed thresholds (scale factors zeroed) make vacuum and analyze fire
  # every ~3-5 days at current churn (~20K deletes + ~20-30K inserts/day),
  # independent of table size and of stats-counter resets.
  #
  # ALTER TABLE ... SET (reloptions) takes only a brief SHARE UPDATE
  # EXCLUSIVE lock — reads and writes are not blocked.
  def up do
    execute """
    ALTER TABLE logs_archived SET (
      autovacuum_vacuum_scale_factor = 0,
      autovacuum_vacuum_threshold = 100000,
      autovacuum_vacuum_insert_scale_factor = 0,
      autovacuum_vacuum_insert_threshold = 100000,
      autovacuum_analyze_scale_factor = 0,
      autovacuum_analyze_threshold = 100000
    )
    """
  end

  def down do
    execute """
    ALTER TABLE logs_archived RESET (
      autovacuum_vacuum_scale_factor,
      autovacuum_vacuum_threshold,
      autovacuum_vacuum_insert_scale_factor,
      autovacuum_vacuum_insert_threshold,
      autovacuum_analyze_scale_factor,
      autovacuum_analyze_threshold
    )
    """
  end
end
