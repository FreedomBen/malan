defmodule Malan.Workers.LogWriter do
  @moduledoc """
  Oban worker that writes audit log entries to the database asynchronously.

  Logs are enqueued from request handlers and written in the background,
  keeping endpoint response times fast while guaranteeing delivery through
  Oban's persistent job queue and retry mechanism.
  """

  use Oban.Worker, queue: :logs, max_attempts: 10

  require Logger

  alias Malan.Accounts.Log
  alias Malan.Repo
  alias Malan.Utils

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt, max_attempts: max_attempts}) do
    %Log{}
    |> Log.create_changeset(args)
    |> Repo.insert()
    |> case do
      {:ok, _log} ->
        :ok

      {:error, changeset} ->
        if attempt >= max_attempts do
          report_log_error(changeset, args)
        end

        {:error, "log insert failed: #{Utils.Ecto.Changeset.errors_to_str(changeset)}"}
    end
  end

  defp report_log_error(changeset, args) do
    msg =
      "Error recording log: user_id: '#{args["user_id"]}', session_id: '#{args["session_id"]}', who: '#{args["who"]}', who_username: '#{args["who_username"]}', verb: '#{args["verb"]}', what: '#{args["what"]}' - Changeset Errors to str:  '#{Utils.Ecto.Changeset.errors_to_str(changeset)}'"

    opts = [
      errors_to_str: Utils.Ecto.Changeset.errors_to_str(changeset),
      user_id: args["user_id"],
      session_id: args["session_id"],
      who: args["who"],
      who_username: args["who_username"],
      verb: args["verb"],
      what: args["what"]
    ]

    unless Application.get_env(:malan, :log_silence_record_log_warning, false) do
      Logger.warning(msg, opts)
    end

    if Application.get_env(:sentry, :dsn) do
      Sentry.capture_message(msg, opts)
    end
  end
end
