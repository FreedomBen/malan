defmodule MalanWeb.TransactionView do
  use MalanWeb, :view

  alias Malan.Accounts.Transaction
  alias MalanWeb.TransactionView

  def render("index.json", %{transactions: transactions}) do
    %{ok: true, data: render_many(transactions, TransactionView, "transaction.json")}
  end

  def render("show.json", %{transaction: transaction}) do
    %{ok: true, data: render_one(transaction, TransactionView, "transaction.json")}
  end

  def render("transaction.json", %{transaction: transaction}) do
    %{
      id: transaction.id,
      success: transaction.success,
      type: Transaction.Type.to_s(transaction.type_enum),
      verb: Transaction.Verb.to_s(transaction.verb_enum),
      when: transaction.when,
      what: transaction.what,
      who: transaction.who,
      user_id: transaction.user_id,
      session_id: transaction.session_id
    }
  end
end
