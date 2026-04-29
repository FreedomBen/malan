defmodule MalanWeb.Plugs.InClusterRequestTest do
  use ExUnit.Case, async: true

  import Plug.Test, only: [conn: 3]

  alias MalanWeb.Plugs.InClusterRequest

  defp build_conn(headers) do
    Enum.reduce(headers, conn(:get, "/", ""), fn {k, v}, acc ->
      Plug.Conn.put_req_header(acc, k, v)
    end)
  end

  describe "exclude_from_force_ssl?/1" do
    test "returns true when no proxy headers are present" do
      assert InClusterRequest.exclude_from_force_ssl?(conn(:get, "/", ""))
    end

    test "returns false when X-Forwarded-For is set (DO LB)" do
      conn = build_conn([{"x-forwarded-for", "203.0.113.7"}])
      refute InClusterRequest.exclude_from_force_ssl?(conn)
    end

    test "returns false when CF-Connecting-IP is set (Cloudflare)" do
      conn = build_conn([{"cf-connecting-ip", "203.0.113.7"}])
      refute InClusterRequest.exclude_from_force_ssl?(conn)
    end

    test "returns false when Forwarded (RFC 7239) is set" do
      conn = build_conn([{"forwarded", "for=203.0.113.7"}])
      refute InClusterRequest.exclude_from_force_ssl?(conn)
    end

    test "returns false when X-Real-IP is set" do
      conn = build_conn([{"x-real-ip", "203.0.113.7"}])
      refute InClusterRequest.exclude_from_force_ssl?(conn)
    end

    test "returns true when only unrelated headers are set" do
      conn = build_conn([{"x-custom-header", "value"}, {"user-agent", "curl/8"}])
      assert InClusterRequest.exclude_from_force_ssl?(conn)
    end

    test "returns false when the proxy header is set to an empty value (still present)" do
      conn = build_conn([{"x-forwarded-for", ""}])
      refute InClusterRequest.exclude_from_force_ssl?(conn)
    end
  end
end
