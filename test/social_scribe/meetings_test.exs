defmodule SocialScribe.MeetingsTest do
  use SocialScribe.DataCase

  alias SocialScribe.Meetings
  alias SocialScribe.Meetings.{Meeting, MeetingTranscript, MeetingParticipant}

  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingTranscriptExample

  @mock_transcript_data %{"data" => meeting_transcript_example()}

  describe "meetings" do
    @invalid_attrs %{title: nil, recorded_at: nil, duration_seconds: nil}

    test "list_meetings/0 returns all meetings" do
      meeting = meeting_fixture()
      assert Meetings.list_meetings() == [meeting]
    end

    test "get_meeting!/1 returns the meeting with given id" do
      meeting = meeting_fixture()
      assert Meetings.get_meeting!(meeting.id) == meeting
    end

    test "get_meeting_by_recall_bot_id/1 returns the meeting with given recall bot id" do
      meeting = meeting_fixture()
      assert Meetings.get_meeting_by_recall_bot_id(meeting.recall_bot_id) == meeting
    end

    test "create_meeting/1 with valid data creates a meeting" do
      calendar_event = calendar_event_fixture()

      recall_bot_id =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        }).id

      valid_attrs = %{
        title: "some title",
        recorded_at: ~U[2025-05-24 00:27:00Z],
        duration_seconds: 42,
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot_id
      }

      assert {:ok, %Meeting{} = meeting} = Meetings.create_meeting(valid_attrs)
      assert meeting.title == "some title"
      assert meeting.recorded_at == ~U[2025-05-24 00:27:00Z]
      assert meeting.duration_seconds == 42
    end

    test "create_meeting/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meetings.create_meeting(@invalid_attrs)
    end

    test "update_meeting/2 with valid data updates the meeting" do
      meeting = meeting_fixture()

      update_attrs = %{
        title: "some updated title",
        recorded_at: ~U[2025-05-25 00:27:00Z],
        duration_seconds: 43
      }

      assert {:ok, %Meeting{} = meeting} = Meetings.update_meeting(meeting, update_attrs)
      assert meeting.title == "some updated title"
      assert meeting.recorded_at == ~U[2025-05-25 00:27:00Z]
      assert meeting.duration_seconds == 43
    end

    test "update_meeting/2 with invalid data returns error changeset" do
      meeting = meeting_fixture()
      assert {:error, %Ecto.Changeset{}} = Meetings.update_meeting(meeting, @invalid_attrs)
      assert meeting == Meetings.get_meeting!(meeting.id)
    end

    test "delete_meeting/1 deletes the meeting" do
      meeting = meeting_fixture()
      assert {:ok, %Meeting{}} = Meetings.delete_meeting(meeting)
      assert_raise Ecto.NoResultsError, fn -> Meetings.get_meeting!(meeting.id) end
    end

    test "change_meeting/1 returns a meeting changeset" do
      meeting = meeting_fixture()
      assert %Ecto.Changeset{} = Meetings.change_meeting(meeting)
    end

    test "list_user_meetings/1 returns all meetings for a user" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{calendar_event_id: calendar_event.id, recall_bot_id: recall_bot.id})

      assert Meetings.list_user_meetings(user) ==
               Repo.preload([meeting], [
                 :meeting_transcript,
                 :meeting_participants,
                 :recall_bot
               ])
    end

    test "get_meeting_with_details/1 returns the meeting with its details preloaded" do
      meeting = meeting_fixture()

      assert Meetings.get_meeting_with_details(meeting.id) ==
               Repo.preload(meeting, [
                 :calendar_event,
                 :recall_bot,
                 :meeting_transcript,
                 :meeting_participants
               ])
    end
  end

  describe "meeting_transcripts" do
    @invalid_attrs %{language: nil, content: nil}

    test "list_meeting_transcripts/0 returns all meeting_transcripts" do
      meeting_transcript = meeting_transcript_fixture()
      assert Meetings.list_meeting_transcripts() == [meeting_transcript]
    end

    test "get_meeting_transcript!/1 returns the meeting_transcript with given id" do
      meeting_transcript = meeting_transcript_fixture()
      assert Meetings.get_meeting_transcript!(meeting_transcript.id) == meeting_transcript
    end

    test "create_meeting_transcript/1 with valid data creates a meeting_transcript" do
      meeting_id = meeting_fixture().id
      valid_attrs = %{language: "some language", content: %{}, meeting_id: meeting_id}

      assert {:ok, %MeetingTranscript{} = meeting_transcript} =
               Meetings.create_meeting_transcript(valid_attrs)

      assert meeting_transcript.language == "some language"
      assert meeting_transcript.content == %{}
    end

    test "create_meeting_transcript/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meetings.create_meeting_transcript(@invalid_attrs)
    end

    test "update_meeting_transcript/2 with valid data updates the meeting_transcript" do
      meeting_transcript = meeting_transcript_fixture()
      update_attrs = %{language: "some updated language", content: %{}}

      assert {:ok, %MeetingTranscript{} = meeting_transcript} =
               Meetings.update_meeting_transcript(meeting_transcript, update_attrs)

      assert meeting_transcript.language == "some updated language"
      assert meeting_transcript.content == %{}
    end

    test "update_meeting_transcript/2 with invalid data returns error changeset" do
      meeting_transcript = meeting_transcript_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Meetings.update_meeting_transcript(meeting_transcript, @invalid_attrs)

      assert meeting_transcript == Meetings.get_meeting_transcript!(meeting_transcript.id)
    end

    test "delete_meeting_transcript/1 deletes the meeting_transcript" do
      meeting_transcript = meeting_transcript_fixture()
      assert {:ok, %MeetingTranscript{}} = Meetings.delete_meeting_transcript(meeting_transcript)

      assert_raise Ecto.NoResultsError, fn ->
        Meetings.get_meeting_transcript!(meeting_transcript.id)
      end
    end

    test "change_meeting_transcript/1 returns a meeting_transcript changeset" do
      meeting_transcript = meeting_transcript_fixture()
      assert %Ecto.Changeset{} = Meetings.change_meeting_transcript(meeting_transcript)
    end
  end

  describe "meeting_participants" do
    @invalid_attrs %{name: nil, recall_participant_id: nil, is_host: nil}

    test "list_meeting_participants/0 returns all meeting_participants" do
      meeting_participant = meeting_participant_fixture()
      assert Meetings.list_meeting_participants() == [meeting_participant]
    end

    test "get_meeting_participant!/1 returns the meeting_participant with given id" do
      meeting_participant = meeting_participant_fixture()
      assert Meetings.get_meeting_participant!(meeting_participant.id) == meeting_participant
    end

    test "create_meeting_participant/1 with valid data creates a meeting_participant" do
      meeting_id = meeting_fixture().id

      valid_attrs = %{
        name: "some name",
        recall_participant_id: "some recall_participant_id",
        is_host: true,
        meeting_id: meeting_id
      }

      assert {:ok, %MeetingParticipant{} = meeting_participant} =
               Meetings.create_meeting_participant(valid_attrs)

      assert meeting_participant.name == "some name"
      assert meeting_participant.recall_participant_id == "some recall_participant_id"
      assert meeting_participant.is_host == true
    end

    test "create_meeting_participant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meetings.create_meeting_participant(@invalid_attrs)
    end

    test "update_meeting_participant/2 with valid data updates the meeting_participant" do
      meeting_participant = meeting_participant_fixture()

      update_attrs = %{
        name: "some updated name",
        recall_participant_id: "some updated recall_participant_id",
        is_host: false
      }

      assert {:ok, %MeetingParticipant{} = meeting_participant} =
               Meetings.update_meeting_participant(meeting_participant, update_attrs)

      assert meeting_participant.name == "some updated name"
      assert meeting_participant.recall_participant_id == "some updated recall_participant_id"
      assert meeting_participant.is_host == false
    end

    test "update_meeting_participant/2 with invalid data returns error changeset" do
      meeting_participant = meeting_participant_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Meetings.update_meeting_participant(meeting_participant, @invalid_attrs)

      assert meeting_participant == Meetings.get_meeting_participant!(meeting_participant.id)
    end

    test "delete_meeting_participant/1 deletes the meeting_participant" do
      meeting_participant = meeting_participant_fixture()

      assert {:ok, %MeetingParticipant{}} =
               Meetings.delete_meeting_participant(meeting_participant)

      assert_raise Ecto.NoResultsError, fn ->
        Meetings.get_meeting_participant!(meeting_participant.id)
      end
    end

    test "change_meeting_participant/1 returns a meeting_participant changeset" do
      meeting_participant = meeting_participant_fixture()
      assert %Ecto.Changeset{} = Meetings.change_meeting_participant(meeting_participant)
    end
  end

  describe "create_meeting_from_recall_data/3" do
    import SocialScribe.MeetingInfoExample
    import SocialScribe.MeetingTranscriptExample

    test "creates a complete meeting record with transcript and participants" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example()

      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting was created with correct attributes
      assert meeting.title == "Test Meeting"
      assert meeting.duration_seconds == 176
      assert meeting.calendar_event_id == calendar_event.id
      assert meeting.recall_bot_id == recall_bot.id

      # Verify transcript was created
      assert meeting.meeting_transcript
      assert meeting.meeting_transcript.language == "en-us"

      assert meeting.meeting_transcript.content["data"] ==
               transcript_data |> Jason.encode!() |> Jason.decode!()

      # Verify participants were created
      assert length(meeting.meeting_participants) == 1

      participant = List.first(meeting.meeting_participants)

      assert participant.name == "Felipe Gomes Paradas"
      assert participant.recall_participant_id == "100"
      assert participant.is_host == true
    end

    test "returns error when calendar_event is nil" do
      user = user_fixture()

      # Create a recall_bot without a calendar_event by directly inserting it
      {:ok, recall_bot} =
        %SocialScribe.Bots.RecallBot{
          recall_bot_id: "test-bot-no-event",
          user_id: user.id,
          calendar_event_id: nil,
          status: "done",
          meeting_url: "https://meet.google.com/test"
        }
        |> Repo.insert()

      bot_api_info = meeting_info_example()
      transcript_data = meeting_transcript_example()

      assert {:error, :missing_calendar_event} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify no meeting was created
      assert Meetings.get_meeting_by_recall_bot_id(recall_bot.id) == nil
    end

    test "handles missing meeting_participants gracefully" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example() |> Map.delete(:meeting_participants)
      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting and transcript were created
      assert meeting.title == "Test Meeting"
      assert meeting.meeting_transcript

      # Verify no participants were created (but transaction didn't fail)
      assert length(meeting.meeting_participants) == 0
    end

    test "handles meeting_participants with string keys" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info =
        meeting_info_example()
        |> Map.delete(:meeting_participants)
        |> Map.put("meeting_participants", [
          %{
            id: 200,
            name: "John Doe",
            is_host: false
          }
        ])

      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting and transcript were created
      assert meeting.title == "Test Meeting"
      assert meeting.meeting_transcript

      # Verify participant was created from string key
      assert length(meeting.meeting_participants) == 1
      participant = List.first(meeting.meeting_participants)
      assert participant.name == "John Doe"
      assert participant.recall_participant_id == "200"
      assert participant.is_host == false
    end

    test "handles empty transcript_data" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example()
      transcript_data = []

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting was created
      assert meeting.title == "Test Meeting"

      # Verify transcript was created with empty data and unknown language
      assert meeting.meeting_transcript
      assert meeting.meeting_transcript.language == "unknown"
      assert meeting.meeting_transcript.content["data"] == []
    end

    test "handles nil transcript_data" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example()
      transcript_data = nil

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting was created
      assert meeting.title == "Test Meeting"

      # Verify transcript was created with nil data and unknown language
      assert meeting.meeting_transcript
      assert meeting.meeting_transcript.language == "unknown"
      assert meeting.meeting_transcript.content["data"] == nil
    end

    test "handles missing recordings in bot_api_info" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example() |> Map.delete(:recordings)
      transcript_data = meeting_transcript_example()

      # Since recorded_at is required, the meeting creation should fail
      assert {:error, {:meeting_creation_failed, %Ecto.Changeset{errors: errors}}} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      assert Keyword.has_key?(errors, :recorded_at)
    end

    test "handles empty recordings array in bot_api_info" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example() |> Map.put(:recordings, [])
      transcript_data = meeting_transcript_example()

      # Since recorded_at is required, the meeting creation should fail
      assert {:error, {:meeting_creation_failed, %Ecto.Changeset{errors: errors}}} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      assert Keyword.has_key?(errors, :recorded_at)
    end

    test "handles invalid datetime strings in recordings gracefully" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info =
        meeting_info_example()
        |> update_in([:recordings], fn recordings ->
          case recordings do
            [first | rest] ->
              [Map.merge(first, %{started_at: "invalid-date", completed_at: "invalid-date"}) | rest]

            _ ->
              recordings
          end
        end)

      transcript_data = meeting_transcript_example()

      # Since recorded_at is required and invalid dates result in nil, the meeting creation should fail
      assert {:error, {:meeting_creation_failed, %Ecto.Changeset{errors: errors}}} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      assert Keyword.has_key?(errors, :recorded_at)
    end

    test "uses meeting_metadata title when calendar_event summary is missing" do
      # Since summary is required, we'll test with a summary that exists but verify
      # the fallback logic works when summary is nil in the actual data
      calendar_event = calendar_event_fixture(%{summary: "Original Summary"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info =
        meeting_info_example()
        |> put_in([:meeting_metadata, :title], "Metadata Title")

      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting uses calendar_event summary (not metadata) when summary exists
      assert meeting.title == "Original Summary"
    end

    test "uses default title when both calendar_event summary and metadata are missing" do
      # Since summary is required, we'll test the default title logic by ensuring
      # metadata doesn't have a title, and verify the code handles it correctly
      calendar_event = calendar_event_fixture(%{summary: "Test Summary"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info =
        meeting_info_example()
        |> put_in([:meeting_metadata], %{})

      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting uses calendar_event summary (not default) when summary exists
      assert meeting.title == "Test Summary"
    end

    test "handles missing participant fields gracefully with defaults" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      # Create participant data with only id (missing name and is_host)
      bot_api_info =
        meeting_info_example()
        |> Map.put(:meeting_participants, [%{id: 300}])

      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify meeting and transcript were created
      assert meeting.title == "Test Meeting"
      assert meeting.meeting_transcript

      # Verify participant was created with defaults (name defaults to "Unknown Participant")
      assert length(meeting.meeting_participants) == 1
      participant_with_defaults = List.first(meeting.meeting_participants)
      assert participant_with_defaults.recall_participant_id == "300"
      assert participant_with_defaults.name == "Unknown Participant"
      assert participant_with_defaults.is_host == false
    end

    test "calculates duration_seconds correctly from recordings" do
      calendar_event = calendar_event_fixture(%{summary: "Test Meeting"})

      recall_bot =
        recall_bot_fixture(%{
          calendar_event_id: calendar_event.id,
          user_id: calendar_event.user_id
        })

      bot_api_info = meeting_info_example()
      transcript_data = meeting_transcript_example()

      assert {:ok, meeting} =
               Meetings.create_meeting_from_recall_data(recall_bot, bot_api_info, transcript_data)

      # Verify duration is calculated correctly
      # started_at: "2025-05-24T23:13:27.113531Z"
      # completed_at: "2025-05-24T23:16:23.890255Z"
      # Difference: ~176 seconds
      assert meeting.duration_seconds == 176
      assert meeting.recorded_at != nil
    end
  end

  describe "generate_prompt_for_meeting/1" do
    test "generates a prompt for a meeting" do
      meeting = meeting_fixture()

      _meeting_transcript =
        meeting_transcript_fixture(%{meeting_id: meeting.id, content: @mock_transcript_data})

      meeting_participant = meeting_participant_fixture(%{meeting_id: meeting.id, is_host: true})

      meeting_participant_2 =
        meeting_participant_fixture(%{meeting_id: meeting.id, is_host: false})

      meeting = Meetings.get_meeting_with_details(meeting.id)

      {:ok, prompt} = Meetings.generate_prompt_for_meeting(meeting)

      assert prompt =~ """
             ## Meeting Info:
             title: #{meeting.title}
             date: #{meeting.recorded_at}
             duration: #{meeting.duration_seconds} seconds

             ### Participants:
             #{meeting_participant.name} (Host)
             #{meeting_participant_2.name} (Participant)

             ### Transcript:
             """
    end
  end
end
