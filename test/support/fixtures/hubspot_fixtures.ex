defmodule SocialScribe.HubspotFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via HubSpot-related contexts.
  """

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  @doc """
  Generate a hubspot_suggestion.
  """
  def hubspot_suggestion_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    # Create a proper meeting with calendar_event
    import SocialScribe.CalendarFixtures
    import SocialScribe.BotsFixtures

    calendar_event = calendar_event_fixture(%{user_id: user_id})
    recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user_id})
    meeting_id = attrs[:meeting_id] || meeting_fixture(%{
      calendar_event_id: calendar_event.id,
      recall_bot_id: recall_bot.id
    }).id

    suggestions_data = attrs[:suggestions] || %{
      "suggestions" => [
        %{
          "field" => "email",
          "current_value" => "old@example.com",
          "suggested_value" => "new@example.com",
          "evidence" => "User said: My new email is new@example.com",
          "timestamp" => "(05:30)"
        }
      ]
    }

    contact_id = attrs[:hubspot_contact_id] || "contact_#{System.unique_integer([:positive])}"

    {:ok, hubspot_suggestion} =
      SocialScribe.HubspotSuggestions.save_suggestions(meeting_id, contact_id, suggestions_data, user_id)

    hubspot_suggestion
  end

  @doc """
  Generate a hubspot_contact_cache.
  """
  def hubspot_contact_cache_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id
    contact_id = attrs[:hubspot_contact_id] || "contact_#{System.unique_integer([:positive])}"

    properties = attrs[:properties] || %{
      "firstname" => "John",
      "lastname" => "Doe",
      "email" => "john.doe@example.com",
      "phone" => "1234567890",
      "company" => "Example Corp",
      "createdate" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "lastmodifieddate" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, cached_contact} =
      SocialScribe.HubspotContactCache.cache_contact(user_id, contact_id, properties)

    cached_contact
  end

  @doc """
  Generate a user_credential for HubSpot.
  """
  def hubspot_credential_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    user_credential_fixture(
      attrs
      |> Enum.into(%{
        user_id: user_id,
        provider: "hubspot",
        token: attrs[:token] || "test_token_#{System.unique_integer([:positive])}",
        refresh_token: attrs[:refresh_token] || "test_refresh_token_#{System.unique_integer([:positive])}",
        expires_at: attrs[:expires_at] || DateTime.add(DateTime.utc_now(), 3600, :second),
        uid: attrs[:uid] || "hubspot_uid_#{System.unique_integer([:positive])}",
        email: attrs[:email] || "hubspot@example.com"
      })
    )
  end

  @doc """
  Generate a meeting with transcript for testing AI suggestions.
  """
  def meeting_with_transcript_fixture(attrs \\ %{}) do
    import SocialScribe.CalendarFixtures
    import SocialScribe.BotsFixtures
    import SocialScribe.MeetingsFixtures

    user_id = attrs[:user_id] || user_fixture().id
    calendar_event = calendar_event_fixture(%{user_id: user_id})
    recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user_id})

    meeting = meeting_fixture(%{
      calendar_event_id: calendar_event.id,
      recall_bot_id: recall_bot.id
    })

    # Create participant
    meeting_participant_fixture(%{
      meeting_id: meeting.id,
      name: "John Doe"
    })

    transcript_data = attrs[:transcript_data] || [
      %{
        "speaker" => "John Doe",
        "words" => [
          %{
            "text" => "My",
            "start_timestamp" => 0.0
          },
          %{
            "text" => "new",
            "start_timestamp" => 0.5
          },
          %{
            "text" => "email",
            "start_timestamp" => 1.0
          },
          %{
            "text" => "is",
            "start_timestamp" => 1.5
          },
          %{
            "text" => "newemail@example.com",
            "start_timestamp" => 2.0
          }
        ],
        "language" => "en-us"
      }
    ]

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{"data" => transcript_data}
    })

    meeting = SocialScribe.Meetings.get_meeting_with_details(meeting.id)
    meeting
  end
end
