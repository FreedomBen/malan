defmodule MalanWeb.PhoneNumberView do
  use MalanWeb, :view
  alias MalanWeb.PhoneNumberView

  def render("index.json", %{phone_numbers: phone_numbers}) do
    %{ok: true, data: render_many(phone_numbers, PhoneNumberView, "phone_number.json")}
  end

  def render("show.json", %{phone_number: phone_number}) do
    %{ok: true, data: render_one(phone_number, PhoneNumberView, "phone_number.json")}
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
