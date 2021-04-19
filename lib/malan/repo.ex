defmodule Malan.Repo do
  use Ecto.Repo,
    otp_app: :malan,
    adapter: Ecto.Adapters.Postgres
end
