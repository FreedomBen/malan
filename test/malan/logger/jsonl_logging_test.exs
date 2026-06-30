defmodule Malan.Logger.JsonlLoggingTest do
  @moduledoc """
  Contract tests for the production stdout JSONL logging (config/runtime.exs,
  LOG_FORMAT=json). Verifies the `LoggerJSON.Formatters.Basic` output shape the
  PLG/Loki stack parses, and that the `EmailScrubber` primary filter still
  redacts emails once the JSON formatter runs.
  """
  use ExUnit.Case, async: true

  alias LoggerJSON.Formatters.Basic
  alias Malan.Logger.EmailScrubber

  @placeholder "[REDACTED_EMAIL]"

  # Keep in sync with the metadata allowlist in config/runtime.exs.
  @prod_metadata [:request_id, :mfa, :file, :line, :pid, :domain, :crash_reason]

  describe "Basic JSONL formatter" do
    test "emits a single JSON object per line with time/severity/message" do
      line = format(%{level: :info, meta: meta(), msg: {:string, "hello world"}})

      assert String.ends_with?(line, "\n")
      # Exactly one line (no embedded newlines before the trailing one).
      assert line |> String.trim_trailing("\n") |> String.contains?("\n") == false

      json = decode(line)
      assert json["severity"] == "info"
      assert json["message"] == "hello world"
      assert json["time"] =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
    end

    test "encodes curated metadata (incl. mfa tuple and pid) under \"metadata\"" do
      meta =
        meta(
          request_id: "REQ-123",
          mfa: {Malan.Accounts, :reset_password, 1},
          file: ~c"lib/malan/accounts.ex",
          line: 42,
          pid: self(),
          domain: [:elixir]
        )

      # Decoding at all proves the non-JSON-native terms (tuple, pid) encoded
      # without crashing the formatter.
      json = decode(format(%{level: :warning, meta: meta, msg: {:string, "boom"}}))

      assert json["metadata"]["request_id"] == "REQ-123"
      assert json["metadata"]["line"] == 42
      # logger_json renders mfa tuples as a readable "Mod.fun/arity" string.
      assert json["metadata"]["mfa"] =~ "reset_password/1"
    end
  end

  describe "EmailScrubber survives JSON formatting" do
    test "redacts an email in a {:string, _} message" do
      event = %{level: :info, meta: meta(), msg: {:string, "reset for foo@bar.com now"}}

      json = event |> EmailScrubber.filter([]) |> format() |> decode()

      assert json["message"] =~ @placeholder
      refute json["message"] =~ "bar.com"
    end

    test "redacts a URL-encoded email in a {:report, _} message" do
      event = %{
        level: :info,
        meta: meta(),
        msg: {:report, %{path: "/api/users/foo%40bar.com/reset_password"}}
      }

      json = event |> EmailScrubber.filter([]) |> format() |> decode()

      assert inspect(json["message"]) =~ @placeholder
      refute inspect(json["message"]) =~ "bar.com"
    end
  end

  describe "migration logging" do
    test "logger_json is started before migrations so Ecto.Migrator logs are JSON" do
      # Malan.Release.migrate/0 runs via Ecto.Migrator.with_repo/2, which does
      # not start the full app. This option ensures the JSON formatter's app is
      # up so migration log lines are JSONL under LOG_FORMAT=json.
      repo_config = Application.fetch_env!(:malan, Malan.Repo)
      assert :logger_json in (repo_config[:start_apps_before_migration] || [])
    end
  end

  # --- helpers ---

  defp meta(extra \\ []) do
    Enum.into(extra, %{time: System.system_time(:microsecond)})
  end

  defp format(event) do
    {formatter, config} = Basic.new(metadata: @prod_metadata)

    event
    |> formatter.format(config)
    |> IO.iodata_to_binary()
  end

  defp decode(line), do: line |> String.trim_trailing() |> Jason.decode!()
end
