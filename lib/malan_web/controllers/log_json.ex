defmodule MalanWeb.LogJSON do
  alias Malan.Accounts.Log

  def index(%{logs: logs}) do
    %{ok: true, data: Enum.map(logs, &log_data/1)}
  end

  def show(%{log: log}) do
    %{ok: true, data: log_data(log)}
  end

  defp log_data(%Log{} = log) do
    %{
      id: log.id,
      success: log.success,
      type: Log.Type.to_s(log.type_enum),
      verb: Log.Verb.to_s(log.verb_enum),
      when: log.when,
      what: log.what,
      who: log.who,
      user_id: log.user_id,
      session_id: log.session_id
    }
  end
end
