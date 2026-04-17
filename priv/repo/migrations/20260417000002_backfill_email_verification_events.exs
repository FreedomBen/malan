defmodule Malan.Repo.Migrations.BackfillEmailVerificationEvents do
  use Ecto.Migration

  import Ecto.Query, warn: false

  @batch_size 1000

  def up do
    # Existing users already have email_verified = nil (the column exists but
    # was never populated by any verification flow). We write one audit row per
    # existing user so the rollout is traceable. No updates to the users table,
    # no emails sent.
    repo = repo()

    query_all_users = """
    SELECT id, email
      FROM users
     WHERE deleted_at IS NULL
       AND id NOT IN (
         SELECT DISTINCT user_id
           FROM email_verification_events
          WHERE event_type = 'backfill_unverified'
       )
     ORDER BY id
    """

    %{rows: rows} = repo.query!(query_all_users)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn chunk ->
      params =
        Enum.flat_map(chunk, fn [uid, email] ->
          [Ecto.UUID.bingenerate(), uid, email, "backfill_unverified", now]
        end)

      placeholders =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {_, i} ->
          base = i * 5
          "($#{base + 1}, $#{base + 2}, $#{base + 3}, $#{base + 4}, $#{base + 5})"
        end)
        |> Enum.join(", ")

      insert_sql =
        "INSERT INTO email_verification_events " <>
          "(id, user_id, email, event_type, inserted_at) VALUES " <>
          placeholders

      repo.query!(insert_sql, params)
    end)
  end

  def down do
    execute "DELETE FROM email_verification_events WHERE event_type = 'backfill_unverified'"
  end
end
