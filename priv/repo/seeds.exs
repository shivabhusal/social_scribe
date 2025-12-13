# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     SocialScribe.Repo.insert!(%SocialScribe.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# seed data to load past meeting with transcripts and all

# Create a test user and credential for the meetings
# user =
#   case SocialScribe.Accounts.get_user_by_email("test@example.com") do
#     nil ->
#       {:ok, user} = SocialScribe.Accounts.register_user(%{
#         email: "test@example.com",
#         password: "password123"
#       })
#       user
#     existing_user ->
#       existing_user
#   end

user = SocialScribe.Accounts.get_user_by_email(System.get_env("USER_EMAIL"))
user_credential = Enum.at(SocialScribe.Repo.all(SocialScribe.Accounts.UserCredential, user_id: user.id, provider: "google"), 0)


# case SocialScribe.Accounts.get_user_credential(user, "google") do
  #   nil ->
  #     {:ok, credential} = SocialScribe.Accounts.create_user_credential(%{
  #       user_id: user.id,
  #       provider: "google",
  #       uid: "test-uid-123",
  #       token: "test-token",
  #       refresh_token: "test-refresh-token",
  #       expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
  #       email: "test@example.com"
  #     })
  #     credential
  #   existing_credential ->
  #     existing_credential
  # end

# Helper function to create a past meeting with contact info change transcript
create_past_meeting_with_contact_change = fn(title, days_ago, transcript_data, participants) ->
  recorded_at = DateTime.add(DateTime.utc_now(), -days_ago * 86400, :second)

  # Create calendar event
  {:ok, calendar_event} = SocialScribe.Calendar.create_calendar_event(%{
    google_event_id: "google-event-#{System.unique_integer([:positive])}",
    summary: title,
    description: "Past meeting about contact info changes",
    html_link: "https://calendar.google.com/event?eid=test",
    status: "confirmed",
    start_time: recorded_at,
    end_time: DateTime.add(recorded_at, 3600, :second),
    user_id: user.id,
    user_credential_id: user_credential.id
  })

  # Create recall bot
  {:ok, recall_bot} = SocialScribe.Bots.create_recall_bot(%{
    recall_bot_id: "recall-bot-#{System.unique_integer([:positive])}",
    status: "completed",
    meeting_url: "https://recall.ai/meeting/test",
    user_id: user.id,
    calendar_event_id: calendar_event.id
  })

  # Create meeting
  {:ok, meeting} = SocialScribe.Meetings.create_meeting(%{
    title: title,
    recorded_at: recorded_at,
    duration_seconds: 3600,
    calendar_event_id: calendar_event.id,
    recall_bot_id: recall_bot.id
  })

  # Create transcript
  transcript_json = transcript_data |> Jason.encode!() |> Jason.decode!()
  {:ok, _transcript} = SocialScribe.Meetings.create_meeting_transcript(%{
    content: %{"data" => transcript_json},
    language: "en-us",
    meeting_id: meeting.id
  })

  # Create participants
  Enum.each(participants, fn participant ->
    SocialScribe.Meetings.create_meeting_participant(%{
      name: participant.name,
      recall_participant_id: participant.recall_participant_id,
      is_host: participant.is_host || false,
      meeting_id: meeting.id
    })
  end)

  meeting
end

# Meeting 1: Phone number change
meeting_1_transcript = [
  %{
    words: [
      %{
        text: "Hi everyone, thanks for joining. I wanted to let you all know that my phone number has changed.",
        language: nil,
        start_timestamp: 0.0,
        end_timestamp: 3.5,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "John Smith",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "My new phone number is 555-123-4567. Please update your contacts.",
        language: nil,
        start_timestamp: 4.0,
        end_timestamp: 7.2,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "John Smith",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "Got it, I'll make sure to update that in our system.",
        language: nil,
        start_timestamp: 8.0,
        end_timestamp: 11.5,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Sarah Johnson",
    speaker_id: 101
  }
]

create_past_meeting_with_contact_change.(
  "Weekly Team Sync - Contact Update",
  7,
  meeting_1_transcript,
  [
    %{name: "John Smith", recall_participant_id: "100", is_host: true},
    %{name: "Sarah Johnson", recall_participant_id: "101", is_host: false}
  ]
)

# Meeting 2: Email address change
meeting_2_transcript = [
  %{
    words: [
      %{
        text: "Before we start, I need to inform everyone that my contact information has changed.",
        language: nil,
        start_timestamp: 0.0,
        end_timestamp: 4.2,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Maria Garcia",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "My new email address is maria.garcia.new@company.com. The old one will be deactivated next week.",
        language: nil,
        start_timestamp: 5.0,
        end_timestamp: 10.5,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Maria Garcia",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "Thanks for letting us know, Maria. I'll update the distribution list.",
        language: nil,
        start_timestamp: 11.0,
        end_timestamp: 14.8,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "David Chen",
    speaker_id: 101
  }
]

create_past_meeting_with_contact_change.(
  "Project Review Meeting",
  14,
  meeting_2_transcript,
  [
    %{name: "Maria Garcia", recall_participant_id: "100", is_host: true},
    %{name: "David Chen", recall_participant_id: "101", is_host: false}
  ]
)

# Meeting 3: Multiple contact info changes
meeting_3_transcript = [
  %{
    words: [
      %{
        text: "Good morning everyone. I have some important updates about my contact information.",
        language: nil,
        start_timestamp: 0.0,
        end_timestamp: 3.8,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Robert Williams",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "I've moved to a new office, so my address has changed to 123 Main Street, Suite 500.",
        language: nil,
        start_timestamp: 4.5,
        end_timestamp: 9.2,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Robert Williams",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "Also, my phone number is now 555-987-6543 and my email is robert.williams@newcompany.com.",
        language: nil,
        start_timestamp: 10.0,
        end_timestamp: 15.5,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Robert Williams",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "I'll send you all an updated business card with the new information.",
        language: nil,
        start_timestamp: 16.0,
        end_timestamp: 19.8,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Robert Williams",
    speaker_id: 100
  }
]

create_past_meeting_with_contact_change.(
  "Client Check-in - Contact Info Update",
  21,
  meeting_3_transcript,
  [
    %{name: "Robert Williams", recall_participant_id: "100", is_host: true},
    %{name: "Emily Davis", recall_participant_id: "101", is_host: false}
  ]
)

# Meeting 4: Contact info change in conversation
meeting_4_transcript = [
  %{
    words: [
      %{
        text: "How can we reach you if we need to follow up on this?",
        language: nil,
        start_timestamp: 0.0,
        end_timestamp: 3.2,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Lisa Anderson",
    speaker_id: 101
  },
  %{
    words: [
      %{
        text: "Oh, actually my contact info has changed recently. My new phone is 555-234-5678.",
        language: nil,
        start_timestamp: 4.0,
        end_timestamp: 9.5,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Michael Brown",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "And my email address changed too. It's now michael.brown.new@email.com.",
        language: nil,
        start_timestamp: 10.0,
        end_timestamp: 14.8,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Michael Brown",
    speaker_id: 100
  },
  %{
    words: [
      %{
        text: "Perfect, I'll make a note of that. Thanks for the update.",
        language: nil,
        start_timestamp: 15.5,
        end_timestamp: 18.2,
        confidence: nil
      }
    ],
    language: "en-us",
    speaker: "Lisa Anderson",
    speaker_id: 101
  }
]

create_past_meeting_with_contact_change.(
  "Sales Follow-up Discussion",
  30,
  meeting_4_transcript,
  [
    %{name: "Michael Brown", recall_participant_id: "100", is_host: true},
    %{name: "Lisa Anderson", recall_participant_id: "101", is_host: false}
  ]
)

IO.puts("✅ Created 4 past meetings with transcripts containing contact info changes")
