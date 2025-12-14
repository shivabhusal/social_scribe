defmodule SocialScribe.Hubspot.HubspotSuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias SocialScribe.Meetings.Meeting
  alias SocialScribe.Accounts.User

  schema "hubspot_suggestions" do
    field :hubspot_contact_id, :string
    field :suggestions, :map

    belongs_to :meeting, Meeting
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(hubspot_suggestion, attrs) do
    hubspot_suggestion
    |> cast(attrs, [:meeting_id, :hubspot_contact_id, :suggestions, :user_id])
    |> validate_required([:meeting_id, :hubspot_contact_id, :suggestions, :user_id])
    |> unique_constraint([:meeting_id, :hubspot_contact_id])
  end
end
