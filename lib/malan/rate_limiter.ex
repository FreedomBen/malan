defmodule Malan.RateLimiter do
  # Redis-backed so rate-limit counters are shared across pods. The default
  # `:fix_window` algorithm stores counts under `Malan.RateLimiter:<bucket>:<window>`;
  # `Malan.RateLimits.clear/1` deletes those keys via SCAN/DEL.
  use Hammer, backend: Hammer.Redis

  @doc """
  Redis key prefix used by the Hammer.Redis backend for this limiter.

  Hammer derives the prefix from the module name (Atom.to_string trimmed of
  the leading "Elixir."), so we mirror that here for callers that need to
  build raw key patterns (e.g. `clear/1` doing SCAN/DEL).
  """
  @spec redis_prefix() :: String.t()
  def redis_prefix, do: "Malan.RateLimiter"
end
