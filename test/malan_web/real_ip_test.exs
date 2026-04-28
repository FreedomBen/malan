defmodule MalanWeb.RealIpTest do
  use ExUnit.Case, async: true

  alias MalanWeb.RealIp

  describe "from_connect_info/1" do
    test "prefers cf-connecting-ip from x_headers over peer_data" do
      info = %{
        x_headers: [{"cf-connecting-ip", "203.0.113.7"}],
        peer_data: %{address: {127, 0, 0, 1}, port: 12_345, ssl_cert: nil}
      }

      assert RealIp.from_connect_info(info) == "203.0.113.7"
    end

    test "is case-insensitive on the header name" do
      info = %{
        x_headers: [{"CF-Connecting-IP", "198.51.100.7"}],
        peer_data: %{address: {127, 0, 0, 1}, port: 1, ssl_cert: nil}
      }

      assert RealIp.from_connect_info(info) == "198.51.100.7"
    end

    test "falls back to peer_data when x_headers is missing" do
      info = %{
        x_headers: nil,
        peer_data: %{address: {10, 0, 0, 5}, port: 1, ssl_cert: nil}
      }

      assert RealIp.from_connect_info(info) == "10.0.0.5"
    end

    test "falls back to peer_data when x_headers has no cf header" do
      info = %{
        x_headers: [{"x-forwarded-for", "1.2.3.4"}, {"user-agent", "curl/8"}],
        peer_data: %{address: {10, 0, 0, 5}, port: 1, ssl_cert: nil}
      }

      assert RealIp.from_connect_info(info) == "10.0.0.5"
    end

    test "falls back to peer_data when cf header is unparseable" do
      info = %{
        x_headers: [{"cf-connecting-ip", "definitely-not-an-ip"}],
        peer_data: %{address: {10, 0, 0, 5}, port: 1, ssl_cert: nil}
      }

      assert RealIp.from_connect_info(info) == "10.0.0.5"
    end

    test "returns 0.0.0.0 when neither x_headers nor peer_data is available" do
      assert RealIp.from_connect_info(%{x_headers: nil, peer_data: nil}) == "0.0.0.0"
    end

    test "returns 0.0.0.0 when input is not a map" do
      assert RealIp.from_connect_info(nil) == "0.0.0.0"
    end

    test "handles IPv6 cf-connecting-ip" do
      info = %{
        x_headers: [{"cf-connecting-ip", "2001:db8::1"}],
        peer_data: nil
      }

      assert RealIp.from_connect_info(info) == "2001:db8::1"
    end
  end

  describe "parse_ip_string/1" do
    test "returns trimmed value for valid IPv4" do
      assert RealIp.parse_ip_string("  192.0.2.1 ") == "192.0.2.1"
    end

    test "returns trimmed value for valid IPv6" do
      assert RealIp.parse_ip_string("::1") == "::1"
    end

    test "returns nil for malformed input" do
      assert RealIp.parse_ip_string("999.999.999.999") == nil
      assert RealIp.parse_ip_string("nope") == nil
      assert RealIp.parse_ip_string("") == nil
      assert RealIp.parse_ip_string(nil) == nil
    end
  end
end
