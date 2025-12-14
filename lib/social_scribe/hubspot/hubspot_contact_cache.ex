defmodule SocialScribe.Hubspot.HubspotContactCache do
  use Ecto.Schema
  import Ecto.Changeset

  alias SocialScribe.Accounts.User

  schema "hubspot_contact_cache" do
    field :hubspot_contact_id, :string
    field :properties, :map
    field :cached_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(hubspot_contact_cache, attrs) do
    hubspot_contact_cache
    |> cast(attrs, [:hubspot_contact_id, :properties, :user_id, :cached_at])
    |> validate_required([:hubspot_contact_id, :properties, :user_id, :cached_at])
    |> unique_constraint([:user_id, :hubspot_contact_id])
  end
end
