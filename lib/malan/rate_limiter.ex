defmodule Malan.RateLimiter do
  use Hammer, backend: :ets
end
