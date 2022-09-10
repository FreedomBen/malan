defmodule Malan.Repo.Migrations.AddRealIpAddressToSessions do
  use Ecto.Migration

  def change do
    alter table("sessions") do
      add :real_ip_address, :string, null: true
    end
  end
end
