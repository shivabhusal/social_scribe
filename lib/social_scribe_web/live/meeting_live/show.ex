defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.HubspotSuggestions

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)

    user_has_automations =
      Automations.list_active_user_automations(socket.assigns.current_user.id)
      |> length()
      |> Kernel.>(0)

    automation_results = Automations.list_automation_results_for_meeting(meeting_id)
    hubspot_suggestions = HubspotSuggestions.list_suggestions_for_meeting(meeting_id)

    if meeting.calendar_event.user_id != socket.assigns.current_user.id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        |> assign(:hubspot_suggestions, hubspot_suggestions)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_suggestions_for_component, contact}, socket) do
    # Forward message to HubSpot update component via send_update
    send_update(SocialScribeWeb.MeetingLive.HubspotUpdateComponent,
      id: "hubspot-update-#{socket.assigns.meeting.id}",
      generate_suggestions_for: contact
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_suggestions, contact}, socket) do
    # Forward message from Task to HubSpot update component
    send_update(SocialScribeWeb.MeetingLive.HubspotUpdateComponent,
      id: "hubspot-update-#{socket.assigns.meeting.id}",
      process_suggestions: contact
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:suggestions_generated, suggestions}, socket) do
    # Forward suggestions result to component
    send_update(SocialScribeWeb.MeetingLive.HubspotUpdateComponent,
      id: "hubspot-update-#{socket.assigns.meeting.id}",
      suggestions_result: suggestions
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:suggestions_error, error}, socket) do
    # Forward error to component
    send_update(SocialScribeWeb.MeetingLive.HubspotUpdateComponent,
      id: "hubspot-update-#{socket.assigns.meeting.id}",
      suggestions_error: error
    )

    {:noreply, socket}
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  defp extract_suggestions(suggestions_map) when is_map(suggestions_map) do
    # Handle both atom and string keys
    suggestions_map
    |> Map.get("suggestions", Map.get(suggestions_map, :suggestions, []))
    |> List.wrap()
  end

  defp extract_suggestions(_), do: []

  defp format_field_name(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_field_name(field) when is_atom(field) do
    field
    |> Atom.to_string()
    |> format_field_name()
  end

  defp format_field_name(_), do: "Unknown Field"

  defp format_value(nil), do: "(empty)"
  defp format_value(""), do: "(empty)"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: to_string(value)

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_datetime()
  end

  defp format_datetime(_), do: "Unknown date"

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <div class="bg-white shadow-xl rounded-lg p-6 md:p-8">
      <h2 class="text-2xl font-semibold mb-4 text-slate-700">
        Meeting Transcript
      </h2>
      <div class="prose prose-sm sm:prose max-w-none h-96 overflow-y-auto pr-2">
        <%= if @has_transcript do %>
          <div :for={segment <- @meeting_transcript.content["data"]} class="mb-3">
            <p>
              <span class="font-semibold text-indigo-600">
                {segment["speaker"] || "Unknown Speaker"}:
              </span>
              {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
            </p>
          </div>
        <% else %>
          <p class="text-slate-500">
            Transcript not available for this meeting.
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
