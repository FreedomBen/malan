defmodule MalanWeb.Plugs.RuntimeSession do
  @moduledoc """
  Wraps `Plug.Session` so the cookie signing/encryption salts are loaded
  from runtime application config (`config/runtime.exs`, populated from
  env vars in prod) rather than being captured at compile time and baked
  into the release.

  The matching LiveView socket reads the same options at WS connect time
  via the `{module, function, args}` form of `:session` in `connect_info`
  — see `MalanWeb.Endpoint.session_options/0`.
  """

  @behaviour Plug

  @impl true
  def init(_opts), do: nil

  @impl true
  def call(conn, _opts), do: Plug.Session.call(conn, session_init())

  # Cache the result of `Plug.Session.init/1` in :persistent_term so the
  # one-time option normalization isn't repeated on every request.
  defp session_init do
    case :persistent_term.get(__MODULE__, :unset) do
      :unset ->
        init = Plug.Session.init(MalanWeb.Endpoint.session_options())
        :persistent_term.put(__MODULE__, init)
        init

      init ->
        init
    end
  end
end
