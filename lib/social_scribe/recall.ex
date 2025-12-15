defmodule SocialScribe.Recall do
  @moduledoc "The real implementation for the Recall.ai API client."
  @behaviour SocialScribe.RecallApi

  defp client do
    api_key = Application.fetch_env!(:social_scribe, :recall_api_key)
    recall_region = Application.fetch_env!(:social_scribe, :recall_region)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://#{recall_region}.recall.ai/api/v1"},
      {Tesla.Middleware.JSON, engine_opts: [keys: :atoms]},
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Token #{api_key}"},
         {"Content-Type", "application/json"},
         {"Accept", "application/json"}
       ]}
    ])
  end

  @impl SocialScribe.RecallApi
  def create_bot(meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      bot_name: "SocialScribe Bot",
      join_at: Timex.format!(join_at, "{ISO:Extended}"),
      recording_config: %{
        transcript: %{provider: %{meeting_captions: %{}}}
      }
    }

    Tesla.post(client(), "/bot", body)
  end

  @impl SocialScribe.RecallApi
  def update_bot(recall_bot_id, meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      join_at: Timex.format!(join_at, "{ISO:Extended}")
    }

    Tesla.patch(client(), "/bot/#{recall_bot_id}", body)
  end

  @impl SocialScribe.RecallApi
  def delete_bot(recall_bot_id) do
    Tesla.delete(client(), "/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot(recall_bot_id) do
    Tesla.get(client(), "/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot_transcript(recall_bot_id) do
    with {:ok, %{body: bot_response}} <- get_bot(recall_bot_id),
         [%{id: recording_id} | _] <- Map.get(bot_response, :recordings, []),
         {:ok, %{body: recording_response}} <- get_recording(recording_id),
         transcript_url when is_binary(transcript_url) <-
           get_in(recording_response, [:media_shortcuts, :transcript, :data, :download_url]) do
      # Fetch transcript from the pre-signed download URL.
      # IMPORTANT: Do NOT send our own Authorization header; the URL already
      # contains all auth info (query params).
      case Tesla.get(transcript_url) do
        {:ok, %Tesla.Env{status: 200, body: transcript_body}} ->
          # Parse JSON string if it's a string, otherwise use as-is
          parsed_transcript =
            case transcript_body do
              transcript_string when is_binary(transcript_string) ->
                case Jason.decode(transcript_string, keys: :atoms) do
                  {:ok, parsed} -> parsed
                  {:error, _} -> transcript_body
                end

              already_parsed ->
                already_parsed
            end

          {:ok, %Tesla.Env{body: parsed_transcript}}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      [] ->
        {:error, :no_recordings}

      nil ->
        {:error, :no_transcript_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_recording(recording_id) do
    Tesla.get(client(), "/recording/#{recording_id}")
  end
end
