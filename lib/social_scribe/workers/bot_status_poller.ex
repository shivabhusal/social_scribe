defmodule SocialScribe.Workers.BotStatusPoller do
  use Oban.Worker, queue: :polling, max_attempts: 3

  alias SocialScribe.Bots
  alias SocialScribe.RecallApi
  alias SocialScribe.Meetings

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    bots_to_poll = Bots.list_pending_bots()

    if Enum.any?(bots_to_poll) do
      Logger.info("Polling #{Enum.count(bots_to_poll)} pending Recall.ai bots...")
    end

    # Also check for bots that are marked as "done" but don't have meetings yet
    # This handles cases where the status was set to "done" but processing failed
    bots_done_but_not_processed =
      Bots.list_recall_bots()
      |> Enum.filter(fn bot ->
        bot.status == "done" && is_nil(Meetings.get_meeting_by_recall_bot_id(bot.id))
      end)

    if Enum.any?(bots_done_but_not_processed) do
      Logger.info(
        "Found #{Enum.count(bots_done_but_not_processed)} bots marked 'done' but not yet processed. Retrying..."
      )

      for bot_record <- bots_done_but_not_processed do
        Logger.info("Retrying processing for done bot: #{inspect(bot_record)}")
        retry_processing_done_bot(bot_record)
      end
    end

    for bot_record <- bots_to_poll do
      Logger.info("Polling bot: #{inspect(bot_record)}")

      # Check if status looks like an HTTP status code (3-digit number)
      # If so, force a re-poll to get the correct status
      if Regex.match?(~r/^\d{3}$/, to_string(bot_record.status)) do
        Logger.warning(
          "Bot #{bot_record.recall_bot_id} has invalid status that looks like HTTP code: #{bot_record.status}. Re-polling to get correct status."
        )
      end

      poll_and_process_bot(bot_record)
    end

    :ok
  end

  defp poll_and_process_bot(bot_record) do
    Logger.info("Polling bot: #{inspect(bot_record)}")

    case RecallApi.get_bot(bot_record.recall_bot_id) do
      # Check for HTTP error status codes
      {:ok, %Tesla.Env{status: status, body: body}} when status >= 400 ->
        Logger.error(
          "Recall API returned error status #{status} for bot #{bot_record.recall_bot_id}: #{inspect(body)}"
        )

        error_status =
          case status do
            404 -> "error"
            _ -> "polling_error"
          end

        Bots.update_recall_bot(bot_record, %{status: error_status})

      # Bot not found on Recall side – 404-style response body
      {:ok, %Tesla.Env{body: %{detail: "Not found."} = body}} ->
        Logger.error(
          "Recall bot #{bot_record.recall_bot_id} not found on Recall.ai: #{inspect(body)}"
        )

        Bots.update_recall_bot(bot_record, %{status: "error"})

      # Successful response – normal happy path
      {:ok, %Tesla.Env{status: status, body: bot_api_info}} when status in [200, 201] ->
        # Log if we get a 201 status (created) - this is unusual for a GET request
        if status == 201 do
          Logger.warning(
            "Received 201 (Created) status for GET bot request for #{bot_record.recall_bot_id}. This is unusual."
          )
        end
        Logger.debug("Bot API info for #{bot_record.recall_bot_id}: #{inspect(bot_api_info, limit: :infinity)}")

        new_status =
          case Map.get(bot_api_info, :status_changes) || Map.get(bot_api_info, "status_changes") do
            nil ->
              Logger.warning(
                "Bot #{bot_record.recall_bot_id} has no status_changes in API response. Keeping current status: #{bot_record.status}"
              )

              bot_record.status

            [] ->
              Logger.warning(
                "Bot #{bot_record.recall_bot_id} has empty status_changes. Keeping current status: #{bot_record.status}"
              )

              bot_record.status

            status_changes when is_list(status_changes) ->
              last_status_change = List.last(status_changes)

              case Map.get(last_status_change, :code) || Map.get(last_status_change, "code") do
                nil ->
                  Logger.warning(
                    "Bot #{bot_record.recall_bot_id} last status_change has no code. Status change: #{inspect(last_status_change)}"
                  )

                  bot_record.status

                status_code ->
                  status_code
              end

            other ->
              Logger.error(
                "Bot #{bot_record.recall_bot_id} has unexpected status_changes format: #{inspect(other)}"
              )

              bot_record.status
          end

        Logger.info("Bot #{bot_record.recall_bot_id} new status: #{new_status} (previous: #{bot_record.status})")

        {:ok, updated_bot_record} = Bots.update_recall_bot(bot_record, %{status: new_status})

        if new_status == "done" &&
             is_nil(Meetings.get_meeting_by_recall_bot_id(updated_bot_record.id)) do
          Logger.info("Bot #{updated_bot_record.recall_bot_id} is done. Processing transcript...")
          process_completed_bot(updated_bot_record, bot_api_info)
        else
          if new_status != bot_record.status do
            Logger.info("Bot #{bot_record.recall_bot_id} status updated to: #{new_status}")
          else
            Logger.debug(
              "Bot #{bot_record.recall_bot_id} status unchanged: #{new_status}. Meeting exists: #{not is_nil(Meetings.get_meeting_by_recall_bot_id(updated_bot_record.id))}"
            )
          end
        end

      {:error, reason} ->
        Logger.error(
          "Failed to poll bot status for #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )

        Bots.update_recall_bot(bot_record, %{status: "polling_error"})
    end
  end

  defp retry_processing_done_bot(bot_record) do
    Logger.info("Retrying processing for bot #{bot_record.recall_bot_id} that is already marked 'done'")

    case RecallApi.get_bot(bot_record.recall_bot_id) do
      {:ok, %Tesla.Env{body: bot_api_info}} ->
        Logger.info("Successfully fetched bot info for retry. Processing...")
        process_completed_bot(bot_record, bot_api_info)

      {:error, reason} ->
        Logger.error(
          "Failed to fetch bot info for retry of #{bot_record.recall_bot_id}: #{inspect(reason)}"
        )
    end
  end

  defp process_completed_bot(bot_record, bot_api_info) do
    Logger.info("Bot #{bot_record.recall_bot_id} is done. Fetching transcript...")

    case RecallApi.get_bot_transcript(bot_record.recall_bot_id) do
      {:ok, %Tesla.Env{body: transcript_data}} ->
        Logger.info("Transcript data: #{inspect(transcript_data)}")
        Logger.info("Successfully fetched transcript for bot #{bot_record.recall_bot_id}")

        case Meetings.create_meeting_from_recall_data(bot_record, bot_api_info, transcript_data) do
          {:ok, meeting} ->
            Logger.info(
              "Successfully created meeting record #{meeting.id} from bot #{bot_record.recall_bot_id}"
            )

            SocialScribe.Workers.AIContentGenerationWorker.new(%{meeting_id: meeting.id})
            |> Oban.insert()

            Logger.info("Enqueued AI content generation for meeting #{meeting.id}")

          {:error, reason} ->
            Logger.error(
              "Failed to create meeting record from bot #{bot_record.recall_bot_id}: #{inspect(reason)}"
            )
        end

      {:error, reason} ->
        Logger.error(
          "Failed to fetch transcript for bot #{bot_record.recall_bot_id} after completion: #{inspect(reason)}"
        )
    end
  end
end
