defmodule MalanWeb.AddressController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  alias Malan.Accounts
  alias Malan.Accounts.Address
  alias MalanWeb.Plugs.EnsureOwnerOrAdmin

  action_fallback MalanWeb.FallbackController

  plug EnsureOwnerOrAdmin,
       [loader: &Accounts.get_address/1, id_param: "id", assign_as: :address]
       when action in [:show, :update, :delete]

  def index(conn, _params) do
    addresses = Accounts.list_addresses_for_user(conn.params["user_id"])
    render(conn, :index, addresses: addresses)
  end

  def create(conn, %{"user_id" => user_id, "address" => address_params}) do
    with {:ok, %Address{} = address} <- Accounts.create_address(user_id, address_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/users/#{user_id}/addresses/#{address}")
      |> render(:show, address: address)
    end
  end

  def show(conn, %{"id" => _id}) do
    address = conn.assigns.address
    render(conn, :show, address: address)
  end

  def update(conn, %{"id" => _id, "address" => address_params}) do
    address = conn.assigns.address

    with {:ok, %Address{} = address} <- Accounts.update_address(address, address_params) do
      render(conn, :show, address: address)
    end
  end

  def delete(conn, %{"id" => _id}) do
    address = conn.assigns.address

    with {:ok, %Address{}} <- Accounts.delete_address(address) do
      send_resp(conn, :no_content, "")
    end
  end
end
