defmodule SocialScribe.HubspotSuggestions do
  @moduledoc """
  The HubspotSuggestions context for managing cached HubSpot AI suggestions.
  """

  import Ecto.Query, warn: false
  alias SocialScribe.Repo
  alias SocialScribe.Hubspot.HubspotSuggestion

  @doc """
  Gets cached suggestions for a meeting and contact.
  """
  def get_cached_suggestions(meeting_id, hubspot_contact_id) do
    Repo.get_by(HubspotSuggestion,
      meeting_id: meeting_id,
      hubspot_contact_id: hubspot_contact_id
    )
  end

  @doc """
  Creates or updates cached suggestions.
  """
  def save_suggestions(meeting_id, hubspot_contact_id, suggestions, user_id) do
    attrs = %{
      meeting_id: meeting_id,
      hubspot_contact_id: hubspot_contact_id,
      suggestions: suggestions,
      user_id: user_id
    }

    case get_cached_suggestions(meeting_id, hubspot_contact_id) do
      nil ->
        %HubspotSuggestion{}
        |> HubspotSuggestion.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> HubspotSuggestion.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes cached suggestions.
  """
  def delete_suggestions(meeting_id, hubspot_contact_id) do
    case get_cached_suggestions(meeting_id, hubspot_contact_id) do
      nil -> {:ok, nil}
      suggestion -> Repo.delete(suggestion)
    end
  end
end
