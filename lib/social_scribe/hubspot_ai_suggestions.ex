defmodule SocialScribe.HubspotAISuggestions do
  @moduledoc """
  Generates AI-suggested HubSpot CRM updates from meeting transcripts.
  """

  alias SocialScribe.Meetings
  alias SocialScribe.AIContentGenerator

  @gemini_model "gemini-2.0-flash-lite"
  @gemini_api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @doc """
  Generates suggested HubSpot contact field updates from a meeting transcript.
  Returns a list of suggested updates with field name, current value, and suggested value.
  Only suggests updates that are explicitly supported by the transcript.
  """
  def generate_suggestions(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = build_suggestion_prompt(meeting_prompt)

        case call_gemini(prompt) do
          {:ok, response_text} ->
            parse_suggestions(response_text)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp build_suggestion_prompt(meeting_prompt) do
    """
    Analyze the following meeting transcript and identify any explicit information that could update a HubSpot CRM contact record.

    IMPORTANT RULES:
    1. Only suggest updates for information that is EXPLICITLY stated in the transcript
    2. Do NOT infer or guess information
    3. Only suggest updates for standard HubSpot contact fields: firstname, lastname, email, phone, company, jobtitle, website, address, city, state, zip, country
    4. Format phone numbers as digits only (e.g., "8885550000" not "888-555-0000")
    5. Return your response as a JSON array of objects with this exact structure:
       [
         {
           "field": "field_name",
           "current_value": "current value or null",
           "suggested_value": "suggested value from transcript",
           "evidence": "exact quote from transcript supporting this update"
         }
       ]
    6. If no updates can be suggested, return an empty array: []

    Meeting Transcript:
    #{meeting_prompt}
    """
  end

  defp call_gemini(prompt_text) do
    api_key = Application.fetch_env!(:social_scribe, :gemini_api_key)
    url = "#{@gemini_api_base_url}/#{@gemini_model}:generateContent?key=#{api_key}"

    payload = %{
      contents: [
        %{
          parts: [%{text: prompt_text}]
        }
      ]
    }

    case Tesla.post(client(), url, payload) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        text_path = [
          "candidates",
          Access.at(0),
          "content",
          "parts",
          Access.at(0),
          "text"
        ]

        case get_in(body, text_path) do
          nil -> {:error, {:parsing_error, "No text content found in Gemini response", body}}
          text_content -> {:ok, text_content}
        end

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp parse_suggestions(response_text) do
    # Try to extract JSON from the response (Gemini might wrap it in markdown)
    json_text =
      response_text
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Jason.decode(json_text) do
      {:ok, suggestions} when is_list(suggestions) ->
        # Validate and filter suggestions
        validated_suggestions =
          suggestions
          |> Enum.filter(fn suggestion ->
            Map.has_key?(suggestion, "field") &&
              Map.has_key?(suggestion, "suggested_value") &&
              suggestion["suggested_value"] != nil &&
              suggestion["suggested_value"] != ""
          end)
          |> Enum.map(fn suggestion ->
            %{
              field: String.to_atom(suggestion["field"]),
              current_value: suggestion["current_value"],
              suggested_value: suggestion["suggested_value"],
              evidence: suggestion["evidence"] || ""
            }
          end)

        {:ok, validated_suggestions}

      {:ok, _} ->
        {:ok, []}

      {:error, _reason} ->
        # If JSON parsing fails, return empty list (no suggestions)
        {:ok, []}
    end
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @gemini_api_base_url},
      Tesla.Middleware.JSON
    ])
  end
end
