defmodule SocialScribe.Repo.Migrations.CreateHubspotSuggestions do
  use Ecto.Migration

  def change do
    create table(:hubspot_suggestions) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :hubspot_contact_id, :string, null: false
      add :suggestions, :map, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:hubspot_suggestions, [:meeting_id])
    create index(:hubspot_suggestions, [:hubspot_contact_id])
    create index(:hubspot_suggestions, [:user_id])
    create unique_index(:hubspot_suggestions, [:meeting_id, :hubspot_contact_id])
  end
end
