defmodule Malan.Repo.Migrations.RemoveRealIpFromSession do
  use Ecto.Migration

  def change do
    alter table("sessions") do
      remove_if_exists :real_ip_address, :string
    end
  end
end
