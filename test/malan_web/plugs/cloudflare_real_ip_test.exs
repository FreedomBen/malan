defmodule MalanWeb.Plugs.CloudflareRealIpTest do
  use ExUnit.Case, async: true

  import Plug.Test, only: [conn: 3]

  alias MalanWeb.Plugs.CloudflareRealIp

  defp build_conn(headers) do
    Enum.reduce(headers, conn(:get, "/", ""), fn {k, v}, acc ->
      Plug.Conn.put_req_header(acc, k, v)
    end)
  end

  describe "call/2" do
    test "rewrites conn.remote_ip from CF-Connecting-IP (IPv4)" do
      conn = build_conn([{"cf-connecting-ip", "203.0.113.7"}])
      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == {203, 0, 113, 7}
    end

    test "rewrites conn.remote_ip from CF-Connecting-IP (IPv6)" do
      conn = build_conn([{"cf-connecting-ip", "2001:db8::1"}])
      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == {8193, 3512, 0, 0, 0, 0, 0, 1}
    end

    test "trims surrounding whitespace before parsing" do
      conn = build_conn([{"cf-connecting-ip", "  198.51.100.42  "}])
      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == {198, 51, 100, 42}
    end

    test "leaves conn.remote_ip unchanged when header is absent" do
      conn = conn(:get, "/", "")
      original = conn.remote_ip

      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == original
    end

    test "ignores unparseable header values and leaves remote_ip alone" do
      conn = build_conn([{"cf-connecting-ip", "not-an-ip"}])
      original = conn.remote_ip

      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == original
    end

    test "ignores empty header values" do
      conn = build_conn([{"cf-connecting-ip", ""}])
      original = conn.remote_ip

      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == original
    end

    test "uses the first CF-Connecting-IP value when multiple are sent" do
      # `put_req_header` deduplicates, so build the conn with raw req_headers
      # to actually inject two distinct values for the same name.
      conn = %{
        conn(:get, "/", "")
        | req_headers: [
            {"cf-connecting-ip", "203.0.113.7"},
            {"cf-connecting-ip", "10.0.0.1"}
          ]
      }

      conn = CloudflareRealIp.call(conn, [])

      assert conn.remote_ip == {203, 0, 113, 7}
    end
  end
end
