-- Run after a large LogArchiver backfill to reclaim dead-tuple space and
-- refresh planner stats. Safe to run on a live database: VACUUM (without
-- FULL) does not take an exclusive lock. ANALYZE refreshes table stats and
-- is essential for the BRIN index on logs_archived to have accurate
-- min/max ranges after a bulk insert.
--
-- Usage:
--   psql "$DATABASE_URL" -f priv/repo/vacuum_logs.sql
--
-- Notes:
--   - Do NOT use VACUUM FULL: it takes an ACCESS EXCLUSIVE lock and rewrites
--     the whole table. Regular VACUUM marks dead tuples reusable, which is
--     what you want here.
--   - If you need to physically reclaim disk space on logs after the
--     backfill, use pg_repack (online, no exclusive lock) instead of FULL.

VACUUM (ANALYZE, VERBOSE) logs;
VACUUM (ANALYZE, VERBOSE) logs_archived;
