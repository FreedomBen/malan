defmodule Malan.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Malan.Accounts` context.
  """

  alias Malan.Accounts
  alias Malan.Test.Helpers

#  def address_fixture(attrs \\ %{}) do
#    {:ok, address} =
#      attrs
#      |> Enum.into(%{
#        "city" => "some city",
#        "country" => "some country",
#        "line_1" => "some line_1",
#        "line_2" => "some line_2",
#        "name" => "some name",
#        "postal" => "some postal",
#        "primary" => true,
#        "state" => "some state",
#        "verified_at" => ~U[2021-12-19 01:54:00Z]
#      })
#      |> Malan.Accounts.create_address()
#
#    address
#  end

  @transaction_valid_attrs %{
    "type" => "users",
    "verb" => "GET",
    "what" => "some what",
    "when" => nil
  }

  def create_transaction(nil, user, session, attrs) do
    Accounts.create_transaction(user.id, session.id, user.id, attrs)
  end

  def create_transaction(user_id, user, session, attrs),
    do: Accounts.create_transaction(user_id, session.id, user.id, attrs)

  @doc """
  Creates a transaction using the specified attrs.  Supports specifying user_id in attrs

  Returns {:ok, user, session, transaction)
  """
  def transaction_fixture(attrs \\ %{}) do
    with {:ok, user, session} <- Helpers.Accounts.regular_user_with_session(),
         %{} = val_attrs <- Map.merge(@transaction_valid_attrs, attrs),
         {:ok, transaction} <-
           create_transaction(
             Map.get(attrs, "user_id"),
             user,
             session,
             val_attrs
           ),
         do: {:ok, user, session, transaction}
  end

  def transaction_fixture_to_retrieved(transaction) do
    %{ transaction | type: nil, verb: nil }
  end

end
