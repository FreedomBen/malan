defmodule Malan.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Malan.Accounts` context.
  """

  def address_fixture(attrs \\ %{}) do
    {:ok, address} =
      attrs
      |> Enum.into(%{
        "city" => "some city",
        "country" => "some country",
        "line_1" => "some line_1",
        "line_2" => "some line_2",
        "name" => "some name",
        "postal" => "some postal",
        "primary" => true,
        "state" => "some state",
        "verified_at" => ~U[2021-12-19 01:54:00Z]
      })
      |> Malan.Accounts.create_address()

    address
  end

  def transaction_fixture(attrs \\ %{}) do
    {:ok, transaction} =
      attrs
      |> Enum.into(%{
        "type" => "some type",
        "verb" => "some verb",
        "what" => "some what",
        "when" => ~U[2021-12-22 21:02:00Z]
      })
      |> Malan.Accounts.create_transaction()

    transaction
  end
end
