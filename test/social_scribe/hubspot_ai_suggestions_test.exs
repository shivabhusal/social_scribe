defmodule SocialScribe.HubspotAISuggestionsTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.HubspotAISuggestions
  alias SocialScribe.Meetings

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "generate_suggestions/1" do
    test "returns error when meeting has no transcript" do
      # Create meeting with participants but no transcript
      meeting = meeting_fixture()
      # Add a participant so we can test transcript error specifically
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Test Participant"})

      # Preload associations
      meeting = Meetings.get_meeting_with_details(meeting.id)
      # No transcript attached (meeting_transcript will be nil)

      assert {:error, :no_transcript} = HubspotAISuggestions.generate_suggestions(meeting)
    end

    test "returns error when meeting has no participants" do
      # Create a meeting without participants
      import SocialScribe.CalendarFixtures
      import SocialScribe.BotsFixtures

      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      {:ok, meeting} = SocialScribe.Meetings.create_meeting(%{
        title: "Test Meeting",
        recorded_at: ~U[2025-05-24 00:27:00Z],
        duration_seconds: 42,
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot.id
      })

      # Create transcript but no participants
      meeting_transcript_fixture(%{
        meeting_id: meeting.id,
        content: %{"data" => [%{"speaker" => "Test", "words" => [], "language" => "en"}]}
      })

      # Reload meeting with transcript (but no participants)
      # meeting_participants will be an empty list []
      meeting = Meetings.get_meeting_with_details(meeting.id)

      # Verify meeting has no participants
      assert meeting.meeting_participants == []

      # The function should return an error when there are no participants
      assert {:error, :no_participants} = HubspotAISuggestions.generate_suggestions(meeting)
    end

    # Note: Full integration tests for Gemini API would require actual API calls
    # or a more sophisticated mocking setup. The module is tested through
    # integration tests in the LiveView components.
  end
end
