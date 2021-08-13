defmodule MalanWeb.PhoneNumberController do
  use MalanWeb, :controller

  alias Malan.Accounts
  alias Malan.Accounts.PhoneNumber

  action_fallback MalanWeb.FallbackController

  def index(conn, _params) do
    phone_numbers = Accounts.list_phone_numbers()
    render(conn, "index.json", phone_numbers: phone_numbers)
  end

  def create(conn, %{"user_id" => user_id, "phone_number" => phone_number_params}) do
    with {:ok, %PhoneNumber{} = phone_number} <- Accounts.create_phone_number(phone_number_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_phone_number_path(conn, :show, user_id, phone_number))
      |> render("show.json", phone_number: phone_number)
    end
  end

  def show(conn, %{"id" => id}) do
    phone_number = Accounts.get_phone_number!(id)
    render(conn, "show.json", phone_number: phone_number)
  end

  def update(conn, %{"id" => id, "phone_number" => phone_number_params}) do
    phone_number = Accounts.get_phone_number!(id)

    with {:ok, %PhoneNumber{} = phone_number} <- Accounts.update_phone_number(phone_number, phone_number_params) do
      render(conn, "show.json", phone_number: phone_number)
    end
  end

  def delete(conn, %{"id" => id}) do
    phone_number = Accounts.get_phone_number!(id)

    with {:ok, %PhoneNumber{}} <- Accounts.delete_phone_number(phone_number) do
      send_resp(conn, :no_content, "")
    end
  end
end
