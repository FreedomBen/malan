defmodule MalanWeb.TransactionView do
  use MalanWeb, :view
  alias MalanWeb.TransactionView

  def render("index.json", %{transactions: transactions}) do
    %{data: render_many(transactions, TransactionView, "transaction.json")}
  end

  def render("show.json", %{transaction: transaction}) do
    %{data: render_one(transaction, TransactionView, "transaction.json")}
  end

  def render("transaction.json", %{transaction: transaction}) do
    %{
      id: transaction.id,
      type: transaction.type,
      verb: transaction.verb,
      when: transaction.when,
      what: transaction.what
    }
  end
end
