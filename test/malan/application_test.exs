defmodule Malan.ApplicationTest do
  use ExUnit.Case, async: true

  describe "Oban default logger" do
    test "is attached at boot for job success and failure events" do
      handler_id = Oban.Telemetry.default_handler_id()

      for event <- [[:oban, :job, :stop], [:oban, :job, :exception]] do
        ids = Enum.map(:telemetry.list_handlers(event), & &1.id)

        assert handler_id in ids,
               "expected #{inspect(handler_id)} attached to #{inspect(event)}, got: #{inspect(ids)}"
      end
    end
  end

  describe "Sentry Oban error reporter" do
    test "is attached to job exception events so all job failures reach Sentry" do
      ids = Enum.map(:telemetry.list_handlers([:oban, :job, :exception]), & &1.id)

      assert Sentry.Integrations.Oban.ErrorReporter in ids,
             "expected Sentry.Integrations.Oban.ErrorReporter attached to " <>
               "[:oban, :job, :exception], got: #{inspect(ids)}"
    end
  end
end
