defmodule MalanWeb.PhoneNumberJSON do
  alias Malan.Accounts.PhoneNumber

  def index(%{phone_numbers: phone_numbers}) do
    %{ok: true, data: Enum.map(phone_numbers, &phone_number_data/1)}
  end

  def show(%{phone_number: phone_number}) do
    %{ok: true, data: phone_number_data(phone_number)}
  end

  def phone_number(%{phone_number: phone_number}), do: phone_number_data(phone_number)
  def phone_number(phone_number), do: phone_number_data(phone_number)

  defp phone_number_data(%PhoneNumber{} = phone_number) do
    %{
      id: phone_number.id,
      user_id: phone_number.user_id,
      primary: phone_number.primary,
      number: phone_number.number,
      verified_at: phone_number.verified_at
    }
  end
end
