defmodule Malan.RepoConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true

  # Regression guard: the Repo must use unnamed prepared statements so it stays
  # safe behind a transaction-mode connection pooler (PgBouncer). Named
  # statements are cached per server connection and break when the pooler hands
  # a later query to a different backend. See config/config.exs.
  test "Repo is configured with prepare: :unnamed for pooler safety" do
    assert Application.get_env(:malan, Malan.Repo)[:prepare] == :unnamed
  end
end
