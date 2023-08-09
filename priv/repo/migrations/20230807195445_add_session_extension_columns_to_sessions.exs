defmodule Malan.Repo.Migrations.AddSessionExtensionColumnsToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :extendable_until, :utc_datetime
      add :max_extension_secs, :integer

      # It is recommended to declare your embeds_many/3 field with type :map in your migrations, instead of using {:array, :map}. Ecto can work with both maps and arrays as the container for embeds (and in most databases maps are represented as JSON which allows Ecto to choose what works best).
      add :extensions, :map
    end
  end
end
