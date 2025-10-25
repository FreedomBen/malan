defmodule MalanWeb.LogJSON do
  use MalanWeb, :view

  alias Malan.Accounts.Log
  alias __MODULE__

  def render("index.json", %{logs: logs}) do
    %{ok: true, data: render_many(logs, LogJSON, "log.json", as: :log)}
  end

  def render("show.json", %{log: log}) do
    %{ok: true, data: render_one(log, LogJSON, "log.json", as: :log)}
  end

  def render("log.json", %{log: log}) do
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
