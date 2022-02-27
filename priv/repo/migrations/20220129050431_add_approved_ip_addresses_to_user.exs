defmodule Malan.Repo.Migrations.AddApprovedIpAddressesToUser do
  use Ecto.Migration

  def change do
    alter table("users") do
      # It's recommened to use :map instead of {:array, :string} with postgres
      # since maps are just jsonb and handle arrays just fine
      # add :approved_ips, {:array, :string}, null: false, default: []
      add :approved_ips, {:array, :string}, null: false, default: []
    end
  end
end
