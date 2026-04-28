defmodule MalanWeb.RealIp do
  @moduledoc """
  Centralized client-IP extraction for the Malan web layer.

  Two transports use this:

    * HTTP requests via `MalanWeb.Plugs.CloudflareRealIp`, which rewrites
      `conn.remote_ip` from the `CF-Connecting-IP` header when present.

    * Phoenix LiveView / channel sockets via `from_connect_info/1`, which
      prefers `cf-connecting-ip` from the `:x_headers` connect_info entry
      (requires the websocket to be configured with
      `connect_info: [:x_headers, :peer_data, ...]`) and falls back to
      `:peer_data`.

  Cloudflare adds `CF-Connecting-IP` on every request that traverses its
  edge to the origin, set to the visitor's real IP. Production
  deployments terminate at Cloudflare, so when the header is present we
  trust it as the authoritative client IP. Unparseable values are
  ignored and the fallback path is used.

  Reference: https://developers.cloudflare.com/fundamentals/reference/http-headers/#cf-connecting-ip
  """

  @cf_header "cf-connecting-ip"
  @fallback "0.0.0.0"

  @doc """
  Returns the client IP as a printable string from a Phoenix socket
  `connect_info` map. Prefers `CF-Connecting-IP` from `:x_headers`,
  falls back to the TCP peer in `:peer_data`, and finally to
  `"0.0.0.0"` when nothing is available.
  """
  def from_connect_info(connect_info) when is_map(connect_info) do
    cloudflare_ip(Map.get(connect_info, :x_headers)) ||
      peer_ip(Map.get(connect_info, :peer_data))
  end

  def from_connect_info(_), do: @fallback

  @doc """
  Picks the `CF-Connecting-IP` value out of an `:x_headers` list and
  returns it as a trimmed string when it parses as a valid IP. Returns
  `nil` if the header is absent, the input is not a list, or the value
  is unparseable.
  """
  def cloudflare_ip(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {name, value} when is_binary(name) and is_binary(value) ->
        if String.downcase(name) == @cf_header, do: value

      _ ->
        nil
    end)
    |> parse_ip_string()
  end

  def cloudflare_ip(_), do: nil

  @doc """
  Parses an IP string. Returns the trimmed string when it is a valid v4
  or v6 address, otherwise `nil`.
  """
  def parse_ip_string(value) when is_binary(value) do
    trimmed = String.trim(value)

    case trimmed |> String.to_charlist() |> :inet.parse_address() do
      {:ok, _ip} -> trimmed
      _ -> nil
    end
  end

  def parse_ip_string(_), do: nil

  @doc """
  Parses an IP string into the Erlang tuple form expected by
  `Plug.Conn.remote_ip`. Returns `{:ok, tuple}` or `:error`.
  """
  def parse_ip_to_tuple(value) when is_binary(value) do
    case value |> String.trim() |> String.to_charlist() |> :inet.parse_address() do
      {:ok, ip} -> {:ok, ip}
      _ -> :error
    end
  end

  def parse_ip_to_tuple(_), do: :error

  defp peer_ip(%{address: address}) when not is_nil(address) do
    address |> :inet.ntoa() |> to_string()
  end

  defp peer_ip(_), do: @fallback
end
