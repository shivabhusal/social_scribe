defmodule SocialScribe.Repo.Migrations.CreateHubspotContactCache do
  use Ecto.Migration

  def change do
    create table(:hubspot_contact_cache) do
      add :hubspot_contact_id, :string, null: false
      add :properties, :map, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:hubspot_contact_cache, [:user_id])
    create index(:hubspot_contact_cache, [:hubspot_contact_id])
    create unique_index(:hubspot_contact_cache, [:user_id, :hubspot_contact_id])
    create index(:hubspot_contact_cache, [:cached_at])
  end
end
