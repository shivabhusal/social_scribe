defmodule SocialScribe.HubspotSuggestionsTest do
  use SocialScribe.DataCase

  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.Hubspot.HubspotSuggestion

  import SocialScribe.HubspotFixtures
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "get_cached_suggestions/2" do
    test "returns nil when no suggestions exist" do
      assert HubspotSuggestions.get_cached_suggestions(999, "nonexistent") == nil
    end

    test "returns cached suggestions when they exist" do
      suggestion = hubspot_suggestion_fixture()
      assert HubspotSuggestions.get_cached_suggestions(suggestion.meeting_id, suggestion.hubspot_contact_id) != nil
    end
  end

  describe "save_suggestions/4" do
    test "creates new suggestions when none exist" do
      user = user_fixture()
      meeting = meeting_fixture()
      contact_id = "contact_123"
      suggestions = %{
        "suggestions" => [
          %{
            "field" => "email",
            "current_value" => "old@example.com",
            "suggested_value" => "new@example.com",
            "evidence" => "Test evidence",
            "timestamp" => "(05:30)"
          }
        ]
      }

      assert {:ok, %HubspotSuggestion{} = saved} =
               HubspotSuggestions.save_suggestions(meeting.id, contact_id, suggestions, user.id)

      assert saved.meeting_id == meeting.id
      assert saved.hubspot_contact_id == contact_id
      assert saved.user_id == user.id
      assert saved.suggestions == suggestions
    end

    test "updates existing suggestions when they exist" do
      suggestion = hubspot_suggestion_fixture()
      user = SocialScribe.Accounts.get_user!(suggestion.user_id)

      new_suggestions = %{
        "suggestions" => [
          %{
            "field" => "phone",
            "current_value" => "1234567890",
            "suggested_value" => "9876543210",
            "evidence" => "Updated evidence",
            "timestamp" => "(10:00)"
          }
        ]
      }

      assert {:ok, %HubspotSuggestion{} = updated} =
               HubspotSuggestions.save_suggestions(
                 suggestion.meeting_id,
                 suggestion.hubspot_contact_id,
                 new_suggestions,
                 user.id
               )

      assert updated.id == suggestion.id
      assert updated.suggestions == new_suggestions
    end

    test "validates required fields" do
      user = user_fixture()

      # Test with missing meeting_id by creating invalid attrs
      invalid_suggestions = %{"suggestions" => []}

      # This should fail validation when trying to create the changeset
      # We test by ensuring the function requires valid parameters
      assert_raise ArgumentError, fn ->
        HubspotSuggestions.save_suggestions(nil, "contact_123", invalid_suggestions, user.id)
      end
    end
  end

  describe "delete_suggestions/2" do
    test "returns ok when suggestions don't exist" do
      assert {:ok, nil} = HubspotSuggestions.delete_suggestions(999, "nonexistent")
    end

    test "deletes existing suggestions" do
      suggestion = hubspot_suggestion_fixture()

      assert {:ok, %HubspotSuggestion{}} =
               HubspotSuggestions.delete_suggestions(suggestion.meeting_id, suggestion.hubspot_contact_id)

      assert HubspotSuggestions.get_cached_suggestions(suggestion.meeting_id, suggestion.hubspot_contact_id) == nil
    end
  end

  describe "list_suggestions_for_meeting/1" do
    test "returns empty list when no suggestions exist" do
      assert HubspotSuggestions.list_suggestions_for_meeting(999) == []
    end

    test "returns all suggestions for a meeting ordered by inserted_at desc" do
      meeting = meeting_fixture()
      user = user_fixture()

      suggestion1 = hubspot_suggestion_fixture(%{meeting_id: meeting.id, user_id: user.id, hubspot_contact_id: "contact_1"})
      :timer.sleep(100) # Ensure different timestamps
      suggestion2 = hubspot_suggestion_fixture(%{meeting_id: meeting.id, user_id: user.id, hubspot_contact_id: "contact_2"})

      suggestions = HubspotSuggestions.list_suggestions_for_meeting(meeting.id)

      assert length(suggestions) == 2
      # Verify ordering - most recent first
      suggestion_ids = Enum.map(suggestions, & &1.id)
      assert suggestion2.id in suggestion_ids
      assert suggestion1.id in suggestion_ids
      # Most recent should be first
      assert hd(suggestions).inserted_at >= List.last(suggestions).inserted_at
    end

    test "only returns suggestions for the specified meeting" do
      meeting1 = meeting_fixture()
      meeting2 = meeting_fixture()
      user = user_fixture()

      hubspot_suggestion_fixture(%{meeting_id: meeting1.id, user_id: user.id})
      hubspot_suggestion_fixture(%{meeting_id: meeting2.id, user_id: user.id})

      suggestions = HubspotSuggestions.list_suggestions_for_meeting(meeting1.id)
      assert length(suggestions) == 1
      assert hd(suggestions).meeting_id == meeting1.id
    end
  end
end
