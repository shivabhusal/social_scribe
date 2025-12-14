defmodule SocialScribeWeb.UserSettingsLive.HubspotUpdateModal do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApi
  alias SocialScribe.HubspotAISuggestions
  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.Meetings
  alias Phoenix.LiveView.JS
  import SocialScribeWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <.modal
      id="hubspot-update-modal"
      show={@show}
      on_cancel={JS.push("close_hubspot_modal") |> hide_modal("hubspot-update-modal")}
    >
      <div class="p-6 max-w-4xl">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-2xl font-bold mb-2 text-slate-800">Update in HubSpot</h2>
            <p class="text-sm text-slate-600">
              Here are suggested updates to sync with your integrations based on this meeting.
            </p>
          </div>
          <%= if @selected_contact && @selected_meeting && not @loading_suggestions && not Enum.empty?(@suggestions) do %>
            <div class="flex items-center gap-2">
              <%= if @using_cached_suggestions do %>
                <span class="text-xs text-slate-500 italic">Using cached suggestions</span>
              <% end %>
              <.button
                phx-click="refetch_suggestions"
                phx-target={@myself}
                phx-disable-with="Refetching..."
                class="text-sm px-3 py-1 border border-slate-300 rounded-md text-slate-700 bg-white hover:bg-slate-50"
              >
                Refetch from AI
              </.button>
            </div>
          <% end %>
        </div>

        <%= if not @hubspot_connected do %>
          <div class="p-4 bg-yellow-50 border border-yellow-200 rounded-md text-yellow-800">
            Please connect your HubSpot account to use this feature.
          </div>
        <% else %>
          <!-- Meeting Selector -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-slate-700 mb-2">Select Meeting</label>
            <.input
              type="select"
              field={@meeting_form[:meeting_id]}
              options={@meeting_options}
              phx-change="select_meeting"
              phx-target={@myself}
            />
          </div>

          <!-- Contact Search -->
          <%= if @selected_meeting do %>
            <div class="mb-6">
              <label class="block text-sm font-medium text-slate-700">Select Contact</label>
              <div class="relative">
                  <.input
                  type="text"
                  field={@search_form[:query]}
                  phx-target={@myself}
                  phx-debounce="300"
                  phx-change="search_contacts"
                  placeholder="Search by name or email..."
                />
                <%= if @search_results && length(@search_results) > 0 do %>
                  <div class="absolute z-10 w-full mt-1 bg-white border border-slate-300 rounded-md shadow-lg max-h-60 overflow-y-auto">
                    <div
                      :for={contact <- @search_results}
                      class="p-3 hover:bg-slate-50 cursor-pointer border-b border-slate-100 last:border-b-0"
                      phx-click="select_contact"
                      phx-value-contact-id={contact.id}
                      phx-target={@myself}
                    >
                      <div class="flex items-center gap-3">
                        <div class="w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 font-semibold">
                          <%= String.first(contact_name(contact)) |> String.upcase() %>
                        </div>
                        <div>
                          <div class="font-medium text-slate-700"><%= contact_name(contact) %></div>
                          <div class="text-sm text-slate-500">
                            <%= contact.properties["email"] || "No email" %>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
              <%= if @search_error do %>
                <p class="mt-2 text-sm text-red-600">{@search_error}</p>
              <% end %>
            </div>

            <!-- Selected Contact Display -->
            <%= if @selected_contact do %>
              <div class="mb-6 p-4 bg-slate-50 rounded-md">
                <div class="flex items-center gap-3">
                  <div class="w-12 h-12 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 font-semibold text-lg">
                    <%= String.first(contact_name(@selected_contact)) |> String.upcase() %>
                  </div>
                  <div>
                    <div class="font-semibold text-slate-800"><%= contact_name(@selected_contact) %></div>
                    <div class="text-sm text-slate-600">
                      <%= @selected_contact.properties["email"] || "No email" %>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Suggestions -->
              <%= if @loading_suggestions do %>
                <div class="text-center py-8">
                  <p class="text-slate-600">Generating AI suggestions...</p>
                </div>
              <% else %>
                <%= if @suggestions_error do %>
                  <div class="p-4 bg-red-50 border border-red-200 rounded-md text-red-800">
                    {@suggestions_error}
                  </div>
                <% else %>
                  <%= if Enum.empty?(@suggestions) do %>
                    <div class="p-4 bg-blue-50 border border-blue-200 rounded-md text-blue-800">
                      No updates suggested. The transcript doesn't contain explicit information that would update this contact.
                    </div>
                  <% else %>
                    <!-- Grouped Suggestions -->
                    <div class="space-y-4 mb-6">
                      <%= for {category, category_suggestions} <- group_suggestions(@suggestions) do %>
                        <div class="border border-slate-200 rounded-lg overflow-hidden">
                          <!-- Category Header -->
                          <div class="bg-slate-50 px-4 py-3 border-b border-slate-200 flex items-center justify-between">
                            <div class="flex items-center gap-3">
                              <input
                                type="checkbox"
                                class="w-4 h-4 text-indigo-600 border-slate-300 rounded focus:ring-indigo-500"
                                checked={all_selected?(@approved_suggestions, category_suggestions)}
                                phx-click="toggle_category"
                                phx-value-category={category}
                                phx-target={@myself}
                              />
                              <span class="font-semibold text-slate-800"><%= format_category_name(category) %></span>
                              <span class="text-sm text-slate-500">
                                (<%= count_selected(@approved_suggestions, category_suggestions) %> update selected)
                              </span>
                            </div>
                            <button
                              type="button"
                              class="text-sm text-indigo-600 hover:text-indigo-800"
                              phx-click="toggle_category_details"
                              phx-value-category={category}
                              phx-target={@myself}
                            >
                              <%= if Map.get(@expanded_categories, category, true) do %>
                                Hide details
                              <% else %>
                                Show details
                              <% end %>
                            </button>
                          </div>

                          <!-- Category Suggestions -->
                          <%= if Map.get(@expanded_categories, category, true) do %>
                            <div class="p-4 space-y-4">
                              <%= for suggestion <- category_suggestions do %>
                                <div class="border-l-2 border-indigo-200 pl-4">
                                  <div class="flex items-start justify-between mb-2">
                                    <div class="flex items-center gap-2">
                                      <input
                                        type="checkbox"
                                        class="w-4 h-4 text-indigo-600 border-slate-300 rounded focus:ring-indigo-500"
                                        checked={Map.get(@approved_suggestions, suggestion.field, false)}
                                        phx-click="toggle_suggestion"
                                        phx-value-field={suggestion.field}
                                        phx-target={@myself}
                                      />
                                      <span class="font-medium text-slate-700">
                                        <%= format_field_name(suggestion.field) %>
                                      </span>
                                    </div>
                                  </div>
                                  <div class="flex items-center gap-3 mb-2">
                                    <div class="flex-1">
                                      <div class="text-xs text-slate-500 mb-1">Current</div>
                                      <div class="px-3 py-2 bg-slate-50 border border-slate-200 rounded text-slate-700">
                                        <%= format_value(suggestion.current_value) %>
                                      </div>
                                    </div>
                                    <div class="text-slate-400 pt-6">→</div>
                                    <div class="flex-1">
                                      <div class="text-xs text-slate-500 mb-1">Suggested</div>
                                      <div class="px-3 py-2 bg-indigo-50 border border-indigo-200 rounded text-indigo-900 font-medium">
                                        <%= format_value(suggestion.suggested_value) %>
                                      </div>
                                    </div>
                                  </div>
                                  <%= if suggestion.evidence && suggestion.evidence != "" do %>
                                    <div class="text-xs text-slate-500 italic mt-1">
                                      Found in transcript
                                      <%= if suggestion.timestamp do %>
                                        (<%= suggestion.timestamp %>)
                                      <% end %>
                                    </div>
                                  <% end %>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>

                    <!-- Summary and Actions -->
                    <div class="border-t border-slate-200 pt-4 mt-6">
                      <div class="flex items-center justify-between mb-4">
                        <p class="text-sm text-slate-600">
                          <%= count_total_selected(@approved_suggestions) %> field<%= if count_total_selected(@approved_suggestions) != 1, do: "s", else: "" %> selected to update
                        </p>
                      </div>
                      <div class="flex justify-end gap-3">
                        <button
                          type="button"
                          phx-click="close_hubspot_modal"
                          class="px-4 py-2 border border-slate-300 rounded-md text-slate-700 bg-white hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500"
                        >
                          Cancel
                        </button>
                        <button
                          type="button"
                          phx-click="update_hubspot"
                          phx-target={@myself}
                          phx-disable-with="Updating..."
                          disabled={Enum.empty?(@approved_suggestions)}
                          class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          Update HubSpot
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              <% end %>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </.modal>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Merge assigns first to ensure current_user is available
    socket = assign(socket, assigns)

    # Only initialize state if not already set (preserve existing state)
    socket =
      socket
      |> assign_new(:meeting_form, fn -> to_form(%{"meeting_id" => ""}) end)
      |> assign_new(:selected_meeting, fn -> nil end)
      |> assign_new(:search_form, fn -> to_form(%{"query" => ""}) end)
      |> assign_new(:search_results, fn -> nil end)
      |> assign_new(:search_error, fn -> nil end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading_suggestions, fn -> false end)
      |> assign_new(:suggestions_error, fn -> nil end)
      |> assign_new(:approved_suggestions, fn -> %{} end)
      |> assign_new(:expanded_categories, fn -> %{} end)
      |> assign_new(:update_success, fn -> false end)
      |> assign_new(:update_error, fn -> nil end)
      |> assign_new(:using_cached_suggestions, fn -> false end)

    # Always update hubspot_credential and meetings (they might change)
    hubspot_credential = Accounts.get_user_credential(socket.assigns.current_user, "hubspot")
    meetings = Meetings.list_user_meetings(socket.assigns.current_user)

    meeting_options =
      [{"Select a meeting...", ""}] ++
        Enum.map(meetings, fn meeting ->
          {meeting.title <> " - " <> format_date(meeting.recorded_at), meeting.id}
        end)

    socket =
      socket
      |> assign(:hubspot_connected, not is_nil(hubspot_credential))
      |> assign(:hubspot_credential, hubspot_credential)
      |> assign(:meeting_options, meeting_options)

    # Check if we need to generate suggestions (forwarded from parent LiveView)
    # Only process if the assign is present and we're not already loading
    socket =
      cond do
        {contact, meeting} = Map.get(socket.assigns, :generate_suggestions_for) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :generate_suggestions_for, nil)

          # Spawn task to generate suggestions asynchronously
          parent_pid = self()
          Task.start(fn ->
            send(parent_pid, {:generate_suggestions, contact, meeting})
          end)
          assign(socket, :loading_suggestions, true)

        {contact, meeting} = Map.get(socket.assigns, :process_suggestions) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :process_suggestions, nil)

          # Process suggestions from Task (forwarded by parent)
          # Generate suggestions asynchronously and update via parent LiveView
          parent_pid = self()
          user = socket.assigns.current_user
          current_values = contact.properties

          Task.start(fn ->
            case HubspotAISuggestions.generate_suggestions(meeting) do
              {:ok, suggestions} ->
                suggestions_with_current =
                  Enum.map(suggestions, fn suggestion ->
                    current_value = Map.get(current_values, Atom.to_string(suggestion.field))
                    %{suggestion | current_value: current_value}
                  end)

                suggestions_for_cache =
                  Enum.map(suggestions_with_current, fn suggestion ->
                    %{
                      "field" => Atom.to_string(suggestion.field),
                      "current_value" => suggestion.current_value,
                      "suggested_value" => suggestion.suggested_value,
                      "evidence" => suggestion.evidence
                    }
                  end)

                HubspotSuggestions.save_suggestions(
                  meeting.id,
                  contact.id,
                  %{"suggestions" => suggestions_for_cache},
                  user.id
                )

                send(parent_pid, {:suggestions_generated, suggestions_with_current})
              {:error, reason} ->
                send(parent_pid, {:suggestions_error, format_error(reason)})
            end
          end)
          assign(socket, :loading_suggestions, true)

        suggestions = Map.get(socket.assigns, :suggestions_result) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :suggestions_result, nil)

          # Suggestions generated successfully
          socket
          |> assign(:suggestions, suggestions)
          |> assign(:loading_suggestions, false)
          |> assign(:suggestions_error, nil)
          |> assign(:using_cached_suggestions, false)

        error = Map.get(socket.assigns, :suggestions_error) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :suggestions_error, nil)

          # Error generating suggestions
          socket
          |> assign(:suggestions, [])
          |> assign(:loading_suggestions, false)
          |> assign(:suggestions_error, error)

        true ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_meeting", %{"meeting_id" => ""}, socket) do
    {:noreply, assign(socket, :selected_meeting, nil)}
  end

  def handle_event("select_meeting", %{"meeting_id" => meeting_id}, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)
    {:noreply, assign(socket, :selected_meeting, meeting)}
  end

  def handle_event("search_contacts", %{"query" => query}, socket) when is_binary(query) do
    handle_search_contacts(query, socket)
  end

  def handle_event("search_contacts", %{"_target" => ["query"], "query" => query}, socket) when is_binary(query) do
    handle_search_contacts(query, socket)
  end

  defp handle_search_contacts(query, socket) do
    if socket.assigns.hubspot_connected && query != "" do
      case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
        {:ok, valid_token} ->
          case HubspotApi.search_contacts(valid_token, query) do
            {:ok, contacts} ->
              updated_credential = Accounts.get_user_credential!(socket.assigns.hubspot_credential.id)

              {:noreply,
               socket
               |> assign(:search_results, contacts)
               |> assign(:search_form, to_form(%{"query" => query}))
               |> assign(:search_error, nil)
               |> assign(:hubspot_credential, updated_credential)}

            {:error, reason} ->
              error_message = format_error(reason)
              {:noreply,
               socket
               |> assign(:search_results, [])
               |> assign(:search_error, error_message)}
          end

        {:error, reason} ->
          error_message = "Failed to refresh token: #{inspect(reason)}"
          {:noreply,
           socket
           |> assign(:search_results, [])
           |> assign(:search_error, error_message)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_contact", %{"contact-id" => contact_id}, socket) do
    if socket.assigns.hubspot_connected && socket.assigns.selected_meeting do
      case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
        {:ok, valid_token} ->
          case HubspotApi.get_contact(valid_token, contact_id) do
            {:ok, contact} ->
              updated_credential = Accounts.get_user_credential!(socket.assigns.hubspot_credential.id)

              # Check for cached suggestions first
              case HubspotSuggestions.get_cached_suggestions(
                     socket.assigns.selected_meeting.id,
                     contact.id
                   ) do
                nil ->
                  # No cache, generate suggestions asynchronously
                  socket =
                    socket
                    |> assign(:selected_contact, contact)
                    |> assign(:suggestions, [])
                    |> assign(:approved_suggestions, %{})
                    |> assign(:loading_suggestions, true)
                    |> assign(:suggestions_error, nil)
                    |> assign(:update_success, false)
                    |> assign(:update_error, nil)
                    |> assign(:hubspot_credential, updated_credential)
                    |> assign(:search_results, nil)
                    |> assign(:using_cached_suggestions, false)

                  # Send message to parent LiveView, which will forward to component
                  send(self(), {:generate_suggestions_for_component, contact, socket.assigns.selected_meeting})

                  {:noreply, socket}

                cached ->
                  # Use cached suggestions
                  suggestions =
                    case cached.suggestions do
                      %{"suggestions" => s} -> s
                      %{suggestions: s} -> s
                      s when is_list(s) -> s
                      _ -> []
                    end

                  current_values = contact.properties

                  suggestions_with_current =
                    Enum.map(suggestions, fn suggestion ->
                      field_str =
                        suggestion["field"] ||
                        suggestion[:field] ||
                        (if is_atom(suggestion["field"]), do: Atom.to_string(suggestion["field"]), else: nil) ||
                        ""

                      field_atom = String.to_atom(field_str)
                      current_value = Map.get(current_values, field_str)

                      %{
                        field: field_atom,
                        current_value: current_value,
                        suggested_value: suggestion["suggested_value"] || suggestion[:suggested_value] || "",
                        evidence: suggestion["evidence"] || suggestion[:evidence] || ""
                      }
                    end)
                    |> Enum.filter(fn s -> s.field != :"" end)

                  {:noreply,
                   socket
                   |> assign(:selected_contact, contact)
                   |> assign(:suggestions, suggestions_with_current)
                   |> assign(:approved_suggestions, %{})
                   |> assign(:loading_suggestions, false)
                   |> assign(:suggestions_error, nil)
                   |> assign(:update_success, false)
                   |> assign(:update_error, nil)
                   |> assign(:hubspot_credential, updated_credential)
                   |> assign(:search_results, nil)
                   |> assign(:using_cached_suggestions, true)}
              end

            {:error, reason} ->
              error_message = format_error(reason)
              {:noreply, assign(socket, :suggestions_error, error_message)}
          end

        {:error, reason} ->
          error_message = "Failed to refresh token: #{inspect(reason)}"
          {:noreply, assign(socket, :suggestions_error, error_message)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_suggestion", %{"field" => field}, socket) do
    field_atom = String.to_atom(field)
    current_approved = socket.assigns.approved_suggestions

    new_approved =
      if Map.has_key?(current_approved, field_atom) do
        Map.delete(current_approved, field_atom)
      else
        Map.put(current_approved, field_atom, true)
      end

    {:noreply, assign(socket, :approved_suggestions, new_approved)}
  end

  def handle_event("toggle_category", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)
    category_suggestions = get_category_suggestions(socket.assigns.suggestions, category_atom)
    all_selected = all_selected?(socket.assigns.approved_suggestions, category_suggestions)

    new_approved =
      if all_selected do
        # Deselect all in category
        Enum.reduce(category_suggestions, socket.assigns.approved_suggestions, fn suggestion, acc ->
          Map.delete(acc, suggestion.field)
        end)
      else
        # Select all in category
        Enum.reduce(category_suggestions, socket.assigns.approved_suggestions, fn suggestion, acc ->
          Map.put(acc, suggestion.field, true)
        end)
      end

    {:noreply, assign(socket, :approved_suggestions, new_approved)}
  end

  def handle_event("toggle_category_details", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)
    current_expanded = socket.assigns.expanded_categories
    new_expanded = Map.update(current_expanded, category_atom, true, &(!&1))

    {:noreply, assign(socket, :expanded_categories, new_expanded)}
  end

  def handle_event("update_hubspot", _params, socket) do
    if socket.assigns.hubspot_connected && socket.assigns.selected_contact do
      properties =
        socket.assigns.suggestions
        |> Enum.filter(fn suggestion ->
          Map.has_key?(socket.assigns.approved_suggestions, suggestion.field)
        end)
        |> Enum.reduce(%{}, fn suggestion, acc ->
          field_name = Atom.to_string(suggestion.field)
          Map.put(acc, field_name, suggestion.suggested_value)
        end)

      if map_size(properties) > 0 do
        case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
          {:ok, valid_token} ->
            case HubspotApi.update_contact(
                   valid_token,
                   socket.assigns.selected_contact.id,
                   properties
                 ) do
              {:ok, _updated_contact} ->
                updated_credential = Accounts.get_user_credential!(socket.assigns.hubspot_credential.id)

                send(self(), {:hubspot_update_success, "Contact updated successfully!"})

                {:noreply,
                 socket
                 |> assign(:update_success, true)
                 |> assign(:update_error, nil)
                 |> assign(:hubspot_credential, updated_credential)}

              {:error, reason} ->
                error_message = format_error(reason)
                {:noreply,
                 socket
                 |> assign(:update_success, false)
                 |> assign(:update_error, error_message)}
            end

          {:error, reason} ->
            error_message = "Failed to refresh token: #{inspect(reason)}"
            {:noreply,
             socket
             |> assign(:update_success, false)
             |> assign(:update_error, error_message)}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:clear_search, socket) do
    {:noreply, assign(socket, :search_results, nil)}
  end

  def handle_info({:generate_suggestions, contact, meeting}, socket) do
    current_values = contact.properties

    case HubspotAISuggestions.generate_suggestions(meeting) do
      {:ok, suggestions} ->
        suggestions_with_current =
          Enum.map(suggestions, fn suggestion ->
            current_value = Map.get(current_values, Atom.to_string(suggestion.field))
            %{suggestion | current_value: current_value}
          end)

        # Store suggestions in cache
        suggestions_for_cache =
          Enum.map(suggestions_with_current, fn suggestion ->
            %{
              "field" => Atom.to_string(suggestion.field),
              "current_value" => suggestion.current_value,
              "suggested_value" => suggestion.suggested_value,
              "evidence" => suggestion.evidence
            }
          end)

        HubspotSuggestions.save_suggestions(
          meeting.id,
          contact.id,
          %{"suggestions" => suggestions_for_cache},
          socket.assigns.current_user.id
        )

        {:noreply,
         socket
         |> assign(:suggestions, suggestions_with_current)
         |> assign(:loading_suggestions, false)
         |> assign(:suggestions_error, nil)
         |> assign(:using_cached_suggestions, false)}

      {:error, reason} ->
        error_message = format_error(reason)
        {:noreply,
         socket
         |> assign(:suggestions, [])
         |> assign(:loading_suggestions, false)
         |> assign(:suggestions_error, error_message)
         |> assign(:using_cached_suggestions, false)}
    end
  end

  def handle_event("refetch_suggestions", _params, socket) do
    if socket.assigns.selected_contact && socket.assigns.selected_meeting do
      # Delete cached suggestions and regenerate
      HubspotSuggestions.delete_suggestions(
        socket.assigns.selected_meeting.id,
        socket.assigns.selected_contact.id
      )

      socket =
        socket
        |> assign(:suggestions, [])
        |> assign(:approved_suggestions, %{})
        |> assign(:loading_suggestions, true)
        |> assign(:suggestions_error, nil)
        |> assign(:using_cached_suggestions, false)

      # Send message to parent LiveView, which will forward to component
      send(self(), {:generate_suggestions_for_component, socket.assigns.selected_contact, socket.assigns.selected_meeting})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp contact_name(contact) do
    first = contact.properties["firstname"] || ""
    last = contact.properties["lastname"] || ""
    email = contact.properties["email"] || ""

    cond do
      first != "" || last != "" -> "#{first} #{last}" |> String.trim()
      email != "" -> email
      true -> "Contact ##{contact.id}"
    end
  end

  defp format_field_name(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_value(nil), do: "(empty)"
  defp format_value(""), do: "(empty)"
  defp format_value(value), do: to_string(value)

  defp format_date(nil), do: "Unknown date"
  defp format_date(datetime) when is_struct(datetime, DateTime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.split("-")
    |> case do
      [year, month, day] ->
        month_name = get_month_name(String.to_integer(month))
        "#{month_name} #{String.to_integer(day)}, #{year}"
      _ -> "Unknown date"
    end
  end

  defp get_month_name(1), do: "January"
  defp get_month_name(2), do: "February"
  defp get_month_name(3), do: "March"
  defp get_month_name(4), do: "April"
  defp get_month_name(5), do: "May"
  defp get_month_name(6), do: "June"
  defp get_month_name(7), do: "July"
  defp get_month_name(8), do: "August"
  defp get_month_name(9), do: "September"
  defp get_month_name(10), do: "October"
  defp get_month_name(11), do: "November"
  defp get_month_name(12), do: "December"

  defp format_error({:api_error, status, message, _body}) do
    "HubSpot API error (#{status}): #{message}"
  end

  defp format_error({:http_error, reason}) do
    "Network error: #{inspect(reason)}"
  end

  defp format_error({:parsing_error, message, _body}) do
    "Error parsing response: #{message}"
  end

  defp format_error(reason) do
    "Error: #{inspect(reason)}"
  end

  defp group_suggestions(suggestions) do
    suggestions
    |> Enum.group_by(fn suggestion ->
      categorize_field(suggestion.field)
    end)
    |> Enum.sort_by(fn {category, _} -> category end)
  end

  defp categorize_field(field) do
    case field do
      :firstname -> :name
      :lastname -> :name
      :email -> :contact_info
      :phone -> :contact_info
      :company -> :company
      :jobtitle -> :company
      :website -> :contact_info
      :address -> :address
      :city -> :address
      :state -> :address
      :zip -> :address
      :country -> :address
      _ -> :other
    end
  end

  defp format_category_name(:name), do: "Name"
  defp format_category_name(:contact_info), do: "Contact Information"
  defp format_category_name(:company), do: "Company"
  defp format_category_name(:address), do: "Address"
  defp format_category_name(:other), do: "Other"

  defp get_category_suggestions(suggestions, category) do
    Enum.filter(suggestions, fn suggestion ->
      categorize_field(suggestion.field) == category
    end)
  end

  defp all_selected?(approved_suggestions, category_suggestions) do
    Enum.all?(category_suggestions, fn suggestion ->
      Map.has_key?(approved_suggestions, suggestion.field)
    end) && length(category_suggestions) > 0
  end

  defp count_selected(approved_suggestions, category_suggestions) do
    Enum.count(category_suggestions, fn suggestion ->
      Map.has_key?(approved_suggestions, suggestion.field)
    end)
  end

  defp count_total_selected(approved_suggestions) do
    map_size(approved_suggestions)
  end
end
