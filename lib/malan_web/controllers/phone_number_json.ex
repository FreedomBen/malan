defmodule MalanWeb.PhoneNumberJSON do
  use MalanWeb, :view
  alias __MODULE__

  def render("index.json", %{phone_numbers: phone_numbers}) do
    %{ok: true, data: render_many(phone_numbers, PhoneNumberJSON, "phone_number.json", as: :phone_number)}
  end

  def render("show.json", %{phone_number: phone_number}) do
    %{ok: true, data: render_one(phone_number, PhoneNumberJSON, "phone_number.json", as: :phone_number)}
  end

  def render("phone_number.json", %{phone_number: phone_number}) do
    %{
      id: phone_number.id,
      user_id: phone_number.user_id,
      primary: phone_number.primary,
      number: phone_number.number,
      verified_at: phone_number.verified_at
    }
  end
end
