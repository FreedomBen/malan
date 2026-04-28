defmodule MalanWeb.Plugs.CloudflareRealIp do
  @moduledoc """
  Replaces `conn.remote_ip` with the IP reported by Cloudflare in the
  `CF-Connecting-IP` request header when present and parseable.

  When the header is absent, malformed, or carries an unparseable value
  the conn is returned unchanged, so this plug is safe to enable in
  environments not behind Cloudflare (dev, test, direct origin probes).

  See `MalanWeb.RealIp` for the trust model and Cloudflare reference.
  """

  @behaviour Plug

  alias MalanWeb.RealIp

  @header "cf-connecting-ip"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case Plug.Conn.get_req_header(conn, @header) do
      [value | _] ->
        case RealIp.parse_ip_to_tuple(value) do
          {:ok, ip_tuple} -> %{conn | remote_ip: ip_tuple}
          :error -> conn
        end

      _ ->
        conn
    end
  end
end
