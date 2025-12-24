defmodule MalanWeb.PhoneNumberController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  alias Malan.Accounts
  alias Malan.Accounts.PhoneNumber
  alias MalanWeb.Plugs.EnsureOwnerOrAdmin

  action_fallback MalanWeb.FallbackController

  plug EnsureOwnerOrAdmin,
       [loader: &Accounts.get_phone_number/1, id_param: "id", assign_as: :phone_number]
       when action in [:show, :update, :delete]

  def index(conn, _params) do
    phone_numbers = Accounts.list_phone_numbers_for_user(conn.params["user_id"])
    render(conn, :index, phone_numbers: phone_numbers)
  end

  def create(conn, %{"user_id" => user_id, "phone_number" => phone_number_params}) do
    with {:ok, %PhoneNumber{} = phone_number} <-
           Accounts.create_phone_number(user_id, phone_number_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/users/#{user_id}/phone_numbers/#{phone_number}")
      |> render(:show, phone_number: phone_number)
    end
  end

  def show(conn, %{"user_id" => _user_id, "id" => _id}) do
    phone_number = conn.assigns.phone_number
    render(conn, :show, phone_number: phone_number)
  end

  def update(conn, %{"user_id" => _user_id, "id" => _id, "phone_number" => phone_number_params}) do
    phone_number = conn.assigns.phone_number

    with {:ok, %PhoneNumber{} = phone_number} <-
           Accounts.update_phone_number(phone_number, phone_number_params) do
      render(conn, :show, phone_number: phone_number)
    end
  end

  def delete(conn, %{"user_id" => _user_id, "id" => _id}) do
    phone_number = conn.assigns.phone_number

    with {:ok, %PhoneNumber{}} <- Accounts.delete_phone_number(phone_number) do
      send_resp(conn, :no_content, "")
    end
  end
end
