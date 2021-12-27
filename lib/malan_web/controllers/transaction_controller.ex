defmodule MalanWeb.TransactionController do
  use MalanWeb, :controller

  alias Malan.Accounts
  alias Malan.Accounts.Transaction

  action_fallback MalanWeb.FallbackController

  plug :is_transaction_user_or_admin when action in [:user_index]

  # User ID of the user who made the change (token owner).
  # Must be the same as the user_id of the event for it to be returned
  def user_index(conn, %{"id" => "current"}) do
    user_index(conn, %{"id" => conn.assigns.authed_user_id})
  end

  def user_index(conn, %{"id" => user_id}) do
    transactions = Accounts.list_transactions(user_id)
    render(conn, "index.json", transactions: transactions)
  end

  def admin_index(conn, _params) do
    transactions = Accounts.list_transactions()
    render(conn, "index.json", transactions: transactions)
  end

  # User ID of the user who made the change (token owner) (Admin endpoint)
  def users(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user_by_id_or_username!(user_id)
    transactions = Accounts.list_transactions(user)
    render(conn, "index.json", transactions: transactions)
  end

  # Session ID of session who made the change
  def sessions(conn, %{"session_id" => session_id}) do
    transactions = Accounts.get_transactions_by!(session_id: session_id)
    render(conn, "index.json", transactions: transactions)
  end

  # User ID of target/who was modified
  def who(conn, %{"user_id" => user_id}) do
    transactions = Accounts.get_transactions_by!(who: user_id)
    render(conn, "index.json", transactions: transactions)
  end

  # Transaction ID
  def show(conn, %{"id" => id}) do
    transaction = Accounts.get_transaction!(id)
    render(conn, "show.json", transaction: transaction)
  end

  # Transactions can't be created directly.
  # They are created as a side effect of other events
  #def create(conn, %{"transaction" => transaction_params}) do
  #  with {:ok, %Transaction{} = transaction} <- Accounts.create_transaction(transaction_params) do
  #    conn
  #    |> put_status(:created)
  #    |> put_resp_header("location", Routes.transaction_path(conn, :show, transaction))
  #    |> render("show.json", transaction: transaction)
  #  end
  #end

  # Transactions are immutable and can't be updated
  #def update(conn, %{"id" => id, "transaction" => transaction_params}) do
  #  transaction = Accounts.get_transaction!(id)

  #  with {:ok, %Transaction{} = transaction} <- Accounts.update_transaction(transaction, transaction_params) do
  #    render(conn, "show.json", transaction: transaction)
  #  end
  #end

  # Transactions are immutable and can't be deleted
  #def delete(conn, %{"id" => id}) do
  #  transaction = Accounts.get_transaction!(id)

  #  with {:ok, %Transaction{}} <- Accounts.delete_transaction(transaction) do
  #    send_resp(conn, :no_content, "")
  #  end
  #end

  defp is_transaction_user_or_admin(conn, _opts) do
    %{user_id: user_id} = Recipes.get_transaction_user(conn.params["recipe_id"])
    cond do
      is_owner?(conn, user_id) || is_admin?(conn) -> conn
      user_id == nil && conn.assigns.authed_user_is_moderator -> conn
      true -> halt_not_owner(conn)
    end
  end
end
