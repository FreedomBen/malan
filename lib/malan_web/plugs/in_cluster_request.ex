defmodule MalanWeb.Plugs.InClusterRequest do
  @moduledoc """
  Predicate used by `Plug.SSL`'s `:exclude` option in prod.

  External traffic reaches malan via Cloudflare → DigitalOcean Load
  Balancer → pod. Both hops add proxy headers (`CF-Connecting-IP` from
  Cloudflare, `X-Forwarded-For` from the LB). In-cluster callers — other
  services dialing the malan Service directly over plain HTTP — never
  touch a proxy, so none of those headers are set.

  We use that to decide whether `Plug.SSL` should redirect to HTTPS:

    * Any proxy header present → external request → enforce HTTPS as usual
      (the LB also sets `X-Forwarded-Proto: https`, so `rewrite_on:
      [:x_forwarded_proto]` already skips the redirect for legitimate
      HTTPS-fronted traffic).
    * No proxy headers → in-cluster caller hitting `http://malan…` →
      skip the HTTPS redirect so the call doesn't 301/307 out to
      `https://accounts.ameelio.org`.

  An attacker can only fabricate the absence of these headers by
  reaching the pod's port 4000 without going through the LB, which
  requires already being inside the cluster network.
  """

  @proxy_headers ~w(x-forwarded-for cf-connecting-ip forwarded x-real-ip)

  @doc """
  Returns `true` when the request has none of the well-known proxy
  headers, indicating it arrived directly from another in-cluster pod
  rather than via Cloudflare or the load balancer.
  """
  @spec exclude_from_force_ssl?(Plug.Conn.t()) :: boolean()
  def exclude_from_force_ssl?(%Plug.Conn{} = conn) do
    Enum.all?(@proxy_headers, &(Plug.Conn.get_req_header(conn, &1) == []))
  end
end
