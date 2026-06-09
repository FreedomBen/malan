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
end
