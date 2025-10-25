defmodule MalanWeb.AddressJSON do
  alias Malan.Accounts.Address

  def index(%{addresses: addresses}) do
    %{ok: true, data: Enum.map(addresses, &address_data/1)}
  end

  def show(%{address: address}) do
    %{ok: true, data: address_data(address)}
  end

  def address(%{address: address}), do: address_data(address)
  def address(address), do: address_data(address)

  defp address_data(%Address{} = address) do
    %{
      id: address.id,
      user_id: address.user_id,
      primary: address.primary,
      verified_at: address.verified_at,
      name: address.name,
      line_1: address.line_1,
      line_2: address.line_2,
      country: address.country,
      city: address.city,
      state: address.state,
      postal: address.postal
    }
  end
end
