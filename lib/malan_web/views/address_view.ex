defmodule MalanWeb.AddressView do
  use MalanWeb, :view
  alias MalanWeb.AddressView

  def render("index.json", %{addresses: addresses}) do
    %{ok: true, data: render_many(addresses, AddressView, "address.json")}
  end

  def render("show.json", %{address: address}) do
    %{ok: true, data: render_one(address, AddressView, "address.json")}
  end

  def render("address.json", %{address: address}) do
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
