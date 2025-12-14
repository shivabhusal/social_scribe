defmodule SocialScribeWeb.MeetingLive.HubspotUpdateComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApi
  alias SocialScribe.HubspotAISuggestions
  alias SocialScribe.HubspotSuggestions
  alias SocialScribe.HubspotContactCache

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <div class="mb-6">
        <h2 class="text-2xl font-semibold text-slate-900 mb-2">Update in HubSpot</h2>
        <p class="text-slate-600">
          Here are suggested updates to sync with your integrations based on this meeting.
        </p>
      </div>

      <%= if not @hubspot_connected do %>
        <div class="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-md">
          <p class="text-yellow-800">
            Please connect your HubSpot account in
            <.link href={~p"/dashboard/settings"} class="font-semibold underline">
              Settings
            </.link>
            to use this feature.
          </p>
        </div>
      <% else %>

        <!-- Contact Search Section -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700">Select Contact</label>

          <div class="relative">
            <%= if @selected_contact do %>
              <div class="mt-2 flex items-center gap-3 p-2 border border-slate-300 rounded-md bg-white">
                <div class="flex-shrink-0 w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold text-xs">
                  <%= contact_initials(@selected_contact) %>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-slate-900 text-sm truncate">
                    <%= contact_name(@selected_contact) %> • <%= @selected_contact.properties["email"] || "No email" %>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="clear_contact"
                  phx-target={@myself}
                  class="text-slate-400 hover:text-slate-600 flex-shrink-0"
                >
                  ✕
                </button>
              </div>
            <% else %>
              <.simple_form
                for={@search_form}
                as={:search}
                phx-target={@myself}
                phx-change="search_contacts"
                phx-submit="fetch_contact_from_hubspot"
              >
                <.input
                  field={@search_form[:query]}
                  type="text"
                  placeholder="Search by name or email..."
                  phx-debounce="300"
                />
              </.simple_form>

              <%= if @search_results do %>
                <div class="absolute top-full left-0 right-0 mt-1 border border-slate-200 rounded-md bg-white max-h-60 overflow-y-auto shadow-lg z-50">
                  <div
                    :for={contact <- @search_results}
                    class="w-full"
                  >
                    <button
                      type="button"
                      class="w-full flex items-center gap-3 p-3 border-b border-slate-100 last:border-0 cursor-pointer hover:bg-slate-50 text-left bg-transparent"
                      phx-click="select_contact"
                      phx-value-contact-id={contact.id}
                      phx-target={@myself}
                    >
                      <div class="flex-shrink-0 w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold text-xs">
                        <%= contact_initials(contact) %>
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="font-medium text-slate-900 text-sm truncate">
                          <%= contact_name(contact) %> • <%= contact.properties["email"] || "No email" %>
                        </div>
                      </div>
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Suggestions Section -->
        <%= if @loading_suggestions do %>
          <div class="py-8 text-center text-slate-600">
            Generating AI suggestions...
          </div>
        <% else %>

          <%= if @suggestions_error do %>
            <div class="p-4 bg-red-50 border border-red-200 rounded-md text-red-800">
              {@suggestions_error}
            </div>
          <% else %>

              <%= if Enum.empty?(@suggestions) do %>
                <div class="p-4 bg-blue-50 border border-blue-200 rounded-md text-blue-800">
                  No updates suggested. The transcript doesn't contain explicit information that would update a contact.
                </div>
              <% else %>
                <div class="space-y-4">
                  <%= for {category, category_suggestions} <- group_suggestions_by_category(@suggestions) do %>
                    <% category_key = category_to_key(category) %>
                    <% expanded = Map.get(@expanded_categories, category_key, true) %>
                    <% selected_count = count_selected_in_category(category_suggestions, @approved_suggestions) %>
                    <% all_selected = selected_count == length(category_suggestions) && length(category_suggestions) > 0 %>

                    <div class="border border-slate-200 rounded-lg">
                      <!-- Category Header -->
                      <div class="bg-slate-50 px-4 py-3 border-b border-slate-200">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-3">
                            <label class="flex items-center cursor-pointer">
                              <input
                                type="checkbox"
                                checked={all_selected}
                                phx-click="toggle_category"
                                phx-value-category={category_key}
                                phx-target={@myself}
                                class="w-4 h-4 text-indigo-600 border-slate-300 rounded focus:ring-indigo-500"
                              />
                            </label>
                            <h3 class="font-semibold text-slate-900"><%= category %></h3>
                          </div>
                          <div class="flex items-center gap-3">
                            <span class="text-sm text-slate-600 bg-slate-200 px-2 py-1 rounded">
                              <%= selected_count %> update<%= pluralize(selected_count) %> selected
                            </span>
                            <button
                              type="button"
                              phx-click="toggle_category_expand"
                              phx-value-category={category_key}
                              phx-target={@myself}
                              class="text-sm text-slate-600 hover:text-slate-900"
                            >
                              <%= if expanded, do: "Hide details", else: "Show details" %>
                            </button>
                          </div>
                        </div>
                      </div>

                      <!-- Category Fields -->
                      <%= if expanded do %>
                        <div class="bg-white divide-y divide-slate-100 overflow-visible">
                          <div
                            :for={suggestion <- category_suggestions}
                            class="px-4 py-4"
                          >
                            <div class="flex items-start gap-4">
                              <label class="flex items-center pt-1">
                                <input
                                  type="checkbox"
                                  checked={Map.get(@approved_suggestions, suggestion.field, false)}
                                  phx-click="toggle_suggestion"
                                  phx-value-field={suggestion.field}
                                  phx-target={@myself}
                                  class="w-4 h-4 text-indigo-600 border-slate-300 rounded focus:ring-indigo-500"
                                />
                              </label>
                              <div class="flex-1">
                                <div class="font-medium text-slate-900 mb-3">
                                  <%= format_field_name(suggestion.field) %>
                                </div>
                                <div class="flex items-start gap-3 mb-3">
                                  <div class="flex-1 flex flex-col">
                                    <input
                                      type="text"
                                      value={if suggestion.current_value && suggestion.current_value != "", do: to_string(suggestion.current_value), else: ""}
                                      placeholder="No existing value"
                                      readonly
                                      class={"w-full px-3 py-2 border border-slate-300 rounded-md bg-slate-50 text-slate-500 text-sm#{if suggestion.current_value && suggestion.current_value != "", do: " line-through", else: ""}"}
                                    />
                                    <button
                                      type="button"
                                      phx-click="toggle_field_editable"
                                      phx-value-field={suggestion.field}
                                      phx-target={@myself}
                                      class={"mt-1 text-xs text-blue-600 hover:text-blue-800 self-start#{if Map.get(@editable_fields, suggestion.field, false), do: " font-medium", else: ""}"}
                                    >
                                      Update mapping
                                    </button>
                                  </div>
                                  <div class="flex items-center pt-2">
                                    <span class="text-slate-600 text-xl font-bold">→</span>
                                  </div>
                                  <div class="flex-1 flex flex-col">
                                    <%= if Map.get(@editable_fields, suggestion.field, false) do %>
                                      <form phx-change="edit_suggested_value" phx-target={@myself} phx-debounce="300" class="flex-1 flex flex-col">
                                        <input
                                          type="hidden"
                                          name="field"
                                          value={suggestion.field}
                                        />
                                        <input
                                          type="text"
                                          name="suggested_value"
                                          value={format_value(Map.get(@edited_suggestions, suggestion.field, suggestion.suggested_value))}
                                          class="w-full px-3 py-2 border border-slate-300 rounded-md bg-white text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                                        />
                                      </form>
                                    <% else %>
                                      <input
                                        type="text"
                                        value={format_value(Map.get(@edited_suggestions, suggestion.field, suggestion.suggested_value))}
                                        disabled
                                        class="w-full px-3 py-2 border border-slate-300 rounded-md bg-slate-50 text-slate-400 text-sm cursor-not-allowed"
                                      />
                                    <% end %>
                                    <%= if suggestion.evidence && suggestion.evidence != "" do %>
                                      <div class="mt-2 text-xs text-slate-500">
                                        <%= if suggestion.timestamp && suggestion.timestamp != "" do %>
                                          <% time_str = format_timestamp(suggestion.timestamp) %>
                                          <div class="relative">
                                            Found in transcript
                                            <button
                                              type="button"
                                              phx-click="show_evidence_tooltip"
                                              phx-value-field={suggestion.field}
                                              phx-target={@myself}
                                              class="text-blue-600 hover:text-blue-800 underline cursor-pointer ml-1"
                                            >
                                              (<%= time_str %>)
                                            </button>
                                            <%= if Map.get(@evidence_tooltips || %{}, suggestion.field) do %>
                                              <div class="absolute left-0 top-full mt-1 z-[9999] w-80 p-3 bg-slate-800 text-white text-xs rounded-md shadow-xl border border-slate-700">
                                                <div class="font-semibold mb-1">Found in transcript:</div>
                                                <div class="italic">"{suggestion.evidence}"</div>
                                                <button
                                                  type="button"
                                                  phx-click="show_evidence_tooltip"
                                                  phx-value-field={suggestion.field}
                                                  phx-target={@myself}
                                                  class="mt-2 text-blue-300 hover:text-blue-100 text-xs underline"
                                                >
                                                  Close
                                                </button>
                                              </div>
                                            <% end %>
                                          </div>
                                        <% else %>
                                          Found in transcript: <span class="ml-1 italic">"{suggestion.evidence}"</span>
                                        <% end %>
                                      </div>
                                    <% end %>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <!-- Footer Summary and Actions -->
                <%= if not @update_success do %>
                  <div class="mt-6 pt-4 border-t border-slate-200 flex items-center justify-between">
                    <div class="text-sm text-slate-600">
                      <%= count_total_selected(@suggestions, @approved_suggestions) %> field<%= pluralize_selected(count_total_selected(@suggestions, @approved_suggestions)) %> selected to update
                    </div>
                    <div class="flex items-center gap-3">
                      <button
                        type="button"
                        phx-click="cancel"
                        phx-target={@myself}
                        class="px-4 py-2 border border-slate-300 rounded-md text-slate-700 bg-white hover:bg-slate-50 font-medium"
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        phx-click="update_hubspot"
                        phx-target={@myself}
                        phx-disable-with="Updating..."
                        disabled={Enum.empty?(@approved_suggestions)}
                        class="px-4 py-2 rounded-md text-white font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                        style="background-color: #10b981;"
                      >
                        Update HubSpot
                      </button>
                    </div>
                  </div>
                <% end %>
              <% end %>
          <% end %>
        <% end %>

        <!-- ✅ Success / Error Messages (NO extra end above this) -->
        <%= if @update_success do %>
          <div class="mt-6 p-4 bg-green-50 border border-green-200 rounded-md">
            <div class="flex items-center justify-between">
              <p class="text-green-800 font-medium">Contact updated successfully!</p>
              <button
                type="button"
                phx-click="cancel"
                phx-target={@myself}
                class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 font-medium"
              >
                Close
              </button>
            </div>
          </div>
        <% end %>

        <%= if @update_error do %>
          <div class="mt-6 p-4 bg-red-50 border border-red-200 rounded-md text-red-800">
            {@update_error}
          </div>
        <% end %>

      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Merge assigns first to ensure current_user and meeting are available
    socket = assign(socket, assigns)

    # Only initialize state if not already set (preserve existing state)
    socket =
      socket
      |> assign_new(:search_form, fn -> to_form(%{"query" => ""}, as: :search) end)
      |> assign_new(:search_results, fn -> nil end)
      |> assign_new(:search_error, fn -> nil end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:loading_contact, fn -> false end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading_suggestions, fn -> false end)
      |> assign_new(:suggestions_error, fn -> nil end)
      |> assign_new(:approved_suggestions, fn -> %{} end)
      |> assign_new(:edited_suggestions, fn -> %{} end)
      |> assign_new(:editable_fields, fn -> %{} end)
      |> assign_new(:evidence_tooltips, fn -> %{} end)
      |> assign_new(:expanded_categories, fn -> %{} end)
      |> assign_new(:update_success, fn -> false end)
      |> assign_new(:update_error, fn -> nil end)
      |> assign_new(:using_cached_suggestions, fn -> false end)
      |> assign_new(:using_cache, fn -> false end)

    # Always update hubspot_credential (it might change)
    hubspot_credential =
      Accounts.get_user_credential(socket.assigns.current_user, "hubspot")

    socket =
      socket
      |> assign(:hubspot_connected, not is_nil(hubspot_credential))
      |> assign(:hubspot_credential, hubspot_credential)

    # Load suggestions for the meeting on mount (even without a contact)
    # Always check cache first, then fetch if needed
    socket =
      if socket.assigns.suggestions == [] && not socket.assigns.loading_suggestions do
        meeting_id = socket.assigns.meeting.id
        user_id = socket.assigns.current_user.id

        # Check for any cached suggestions for this meeting
        cached_suggestions_list = HubspotSuggestions.list_suggestions_for_meeting(meeting_id)

        if Enum.any?(cached_suggestions_list) do
          # Use the first cached suggestion (they're ordered by inserted_at desc)
          cached = List.first(cached_suggestions_list)

          suggestions =
            case cached.suggestions do
              %{"suggestions" => s} -> s
              %{suggestions: s} -> s
              s when is_list(s) -> s
              _ -> []
            end

          # Convert to our format - always set current_value to nil when no contact is selected
          # This ensures we don't show stale values from a previous contact
          suggestions_without_current =
            Enum.map(suggestions, fn suggestion ->
              field_str =
                suggestion["field"] ||
                suggestion[:field] ||
                (if is_atom(suggestion["field"]), do: Atom.to_string(suggestion["field"]), else: nil) ||
                ""

              field_atom = if field_str != "", do: String.to_atom(field_str), else: :""

              %{
                field: field_atom,
                current_value: nil,  # Always nil when no contact is selected
                suggested_value: suggestion["suggested_value"] || suggestion[:suggested_value] || "",
                evidence: suggestion["evidence"] || suggestion[:evidence] || "",
                timestamp: suggestion["timestamp"] || suggestion[:timestamp] || nil
              }
            end)
            |> Enum.filter(fn s -> s.field != :"" end)

          socket
          |> assign(:suggestions, suggestions_without_current)
          |> assign(:loading_suggestions, false)
          |> assign(:suggestions_error, nil)
          |> assign(:using_cached_suggestions, true)
          |> assign(:editable_fields, %{})
        else
          # No cache, generate suggestions
          if connected?(socket) do
            send(self(), {:load_meeting_suggestions, meeting_id, user_id})
            assign(socket, :loading_suggestions, true)
          else
            socket
          end
        end
      else
        socket
      end

    # Load meeting suggestions (without contact) - generate and cache
    socket =
      if load_data = Map.get(socket.assigns, :load_meeting_suggestions) do
        {meeting_id, user_id} = load_data
        socket = assign(socket, :load_meeting_suggestions, nil)
        meeting = socket.assigns.meeting

        # Generate suggestions for the meeting (without contact)
        parent_pid = self()

        Task.start(fn ->
          case HubspotAISuggestions.generate_suggestions(meeting) do
            {:ok, suggestions} ->
              # Suggestions without current values (no contact selected yet)
              suggestions_without_current =
                Enum.map(suggestions, fn suggestion ->
                  %{
                    field: suggestion.field,
                    current_value: nil,
                    suggested_value: suggestion.suggested_value,
                    evidence: suggestion.evidence || "",
                    timestamp: suggestion.timestamp || nil
                  }
                end)

              # Cache the suggestions with a placeholder contact_id for meeting-level suggestions
              # Use "meeting_#{meeting_id}" as a placeholder contact_id
              placeholder_contact_id = "meeting_#{meeting_id}"

              suggestions_for_cache =
                Enum.map(suggestions_without_current, fn suggestion ->
                  %{
                    "field" => Atom.to_string(suggestion.field),
                    "current_value" => suggestion.current_value,
                    "suggested_value" => suggestion.suggested_value,
                    "evidence" => suggestion.evidence,
                    "timestamp" => suggestion.timestamp
                  }
                end)

              HubspotSuggestions.save_suggestions(
                meeting_id,
                placeholder_contact_id,
                %{"suggestions" => suggestions_for_cache},
                user_id
              )

              send(parent_pid, {:meeting_suggestions_loaded, suggestions_without_current})

            {:error, reason} ->
              send(parent_pid, {:suggestions_error, format_error(reason)})
          end
        end)

        assign(socket, :loading_suggestions, true)
      else
        socket
      end

    # Handle contact loaded from async task
    socket =
      if contact_data = Map.get(socket.assigns, :contact_loaded) do
        {contact, updated_credential, cached_suggestions} = contact_data
        socket = assign(socket, :contact_loaded, nil)
        socket = assign(socket, :loading_contact, false)

        socket =
          socket
          |> assign(:selected_contact, contact)
          |> assign(:approved_suggestions, %{})
          |> assign(:edited_suggestions, %{})
          |> assign(:editable_fields, %{})
          |> assign(:suggestions_error, nil)
          |> assign(:update_success, false)
          |> assign(:update_error, nil)
          |> assign(:hubspot_credential, updated_credential)

        # Always update suggestions with the selected contact's current values
        # This ensures we show the correct current values for the selected contact
        current_values = contact.properties

        # Get suggestions from cache or use existing ones
        suggestions_to_update = if cached_suggestions do
          # Use cached suggestions structure
          case cached_suggestions.suggestions do
            %{"suggestions" => s} -> s
            %{suggestions: s} -> s
            s when is_list(s) -> s
            _ -> []
          end
        else
          # Use existing suggestions from socket
          socket.assigns.suggestions
          |> Enum.map(fn suggestion ->
            %{
              "field" => Atom.to_string(suggestion.field),
              "suggested_value" => suggestion.suggested_value,
              "evidence" => suggestion.evidence || "",
              "timestamp" => suggestion.timestamp || nil
            }
          end)
        end

        # Always update with the contact's current values (fresh from HubSpot)
        suggestions_with_current =
          Enum.map(suggestions_to_update, fn suggestion ->
            field_str =
              if is_map(suggestion) do
                suggestion["field"] ||
                suggestion[:field] ||
                (if is_atom(suggestion["field"]), do: Atom.to_string(suggestion["field"]), else: nil) ||
                ""
              else
                ""
              end

            field_atom = if field_str != "", do: String.to_atom(field_str), else: :""

            # Get current value from the contact's properties (fresh from HubSpot)
            current_value = Map.get(current_values, field_str)

            %{
              field: field_atom,
              current_value: current_value,
              suggested_value:
                if is_map(suggestion) do
                  suggestion["suggested_value"] || suggestion[:suggested_value] || ""
                else
                  suggestion.suggested_value || ""
                end,
              evidence:
                if is_map(suggestion) do
                  suggestion["evidence"] || suggestion[:evidence] || ""
                else
                  suggestion.evidence || ""
                end,
              timestamp:
                if is_map(suggestion) do
                  suggestion["timestamp"] || suggestion[:timestamp] || nil
                else
                  Map.get(suggestion, :timestamp) || nil
                end
            }
          end)
          |> Enum.filter(fn s -> s.field != :"" end)

        socket
        |> assign(:suggestions, suggestions_with_current)
        |> assign(:loading_suggestions, false)
        |> assign(:suggestions_error, nil)
        |> assign(:using_cached_suggestions, not is_nil(cached_suggestions))
      else
        socket
      end

    # Handle contact load error
    socket =
      if error_message = Map.get(socket.assigns, :contact_load_error) do
        socket
        |> assign(:contact_load_error, nil)
        |> assign(:loading_contact, false)
        |> assign(:search_error, error_message)
        |> assign(:selected_contact, nil)
      else
        socket
      end

    # Handle meeting suggestions loaded (without contact)
    socket =
      if suggestions = Map.get(socket.assigns, :meeting_suggestions_loaded) do
        socket
        |> assign(:meeting_suggestions_loaded, nil)
        |> assign(:suggestions, suggestions)
        |> assign(:loading_suggestions, false)
        |> assign(:suggestions_error, nil)
      else
        socket
      end

    # Check if we need to generate suggestions (forwarded from parent LiveView)
    # Only process if the assign is present and we're not already loading
    socket =
      cond do
        contact = Map.get(socket.assigns, :generate_suggestions_for) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :generate_suggestions_for, nil)

          # Spawn task to generate suggestions asynchronously
          parent_pid = self()
          Task.start(fn ->
            send(parent_pid, {:generate_suggestions, contact})
          end)
          assign(socket, :loading_suggestions, true)

        contact = Map.get(socket.assigns, :process_suggestions) ->
          # Remove the assign to prevent reprocessing
          socket = assign(socket, :process_suggestions, nil)

          # Process suggestions from Task (forwarded by parent)
          # Generate suggestions asynchronously and update via parent LiveView
          parent_pid = self()
          meeting = socket.assigns.meeting
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
                      "evidence" => suggestion.evidence,
                      "timestamp" => suggestion.timestamp
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
  def handle_event("search_contacts", params, socket) do
    require Logger

    # Extract query from params - could be nested in "search" or direct
    query =
      cond do
        Map.has_key?(params, "search") && Map.has_key?(params["search"], "query") ->
          params["search"]["query"]

        Map.has_key?(params, "query") ->
          params["query"]

        true ->
          ""
      end
      |> String.trim()

    Logger.debug("Search contacts event triggered with query: '#{query}', params: #{inspect(params)}")

    # Update form value
    socket = assign(socket, :search_form, to_form(%{"query" => query}, as: :search))

    if socket.assigns.hubspot_connected && byte_size(query) >= 3 do
      Logger.debug("Searching HubSpot for query: '#{query}'")
      # First, check cache
      cached_results = HubspotContactCache.search_cached_contacts(
        socket.assigns.current_user.id,
        query
      )

      if Enum.any?(cached_results) do
        Logger.debug("Found #{length(cached_results)} cached results")
        # Show cached results immediately
        {:noreply,
         socket
         |> assign(:search_results, cached_results)
         |> assign(:search_error, nil)
         |> assign(:using_cache, true)}
      else
        Logger.debug("No cache found, searching HubSpot API")
        # No cache, search HubSpot API
        case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
          {:ok, valid_token} ->
            Logger.debug("Token validated, calling HubSpot API")
            case HubspotApi.search_contacts(valid_token, query) do
              {:ok, contacts} ->
                Logger.debug("HubSpot API returned #{length(contacts)} contacts")
                # Cache the results
                Enum.each(contacts, fn contact ->
                  HubspotContactCache.cache_contact(
                    socket.assigns.current_user.id,
                    contact.id,
                    contact.properties
                  )
                end)

                # Reload credential in case token was refreshed
                updated_credential = Accounts.get_user_credential!(
                  socket.assigns.hubspot_credential.id
                )

                {:noreply,
                 socket
                 |> assign(:search_results, contacts)
                 |> assign(:search_error, nil)
                 |> assign(:using_cache, false)
                 |> assign(:hubspot_credential, updated_credential)}

              {:error, reason} ->
                error_message = format_error(reason)
                {:noreply,
                 socket
                 |> assign(:search_results, [])
                 |> assign(:search_error, error_message)
                 |> assign(:using_cache, false)}
            end

          {:error, reason} ->
            error_message = "Failed to refresh token: #{inspect(reason)}"
            {:noreply,
             socket
             |> assign(:search_results, [])
             |> assign(:search_error, error_message)
             |> assign(:using_cache, false)}
        end
      end
    else
      Logger.debug("Query too short (#{byte_size(query)} chars) or HubSpot not connected")
      # Clear results if query is too short
      {:noreply,
       socket
       |> assign(:search_results, nil)
       |> assign(:search_error, nil)
       |> assign(:using_cache, false)}
    end
  end

  def handle_event("fetch_contact_from_hubspot", params, socket) do
    # Extract query from params - could be nested in "search" or direct
    query =
      cond do
        Map.has_key?(params, "search") && Map.has_key?(params["search"], "query") ->
          params["search"]["query"]

        Map.has_key?(params, "query") ->
          params["query"]

        true ->
          ""
      end
      |> String.trim()

    # When Enter is pressed, fetch fresh data from HubSpot and update cache
    if socket.assigns.hubspot_connected && query != "" do
      case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
        {:ok, valid_token} ->
          case HubspotApi.search_contacts(valid_token, query) do
            {:ok, contacts} ->
              # Update cache with fresh data
              Enum.each(contacts, fn contact ->
                HubspotContactCache.cache_contact(
                  socket.assigns.current_user.id,
                  contact.id,
                  contact.properties
                )
              end)

              # Reload credential in case token was refreshed
              updated_credential = Accounts.get_user_credential!(
                socket.assigns.hubspot_credential.id
              )

              {:noreply,
               socket
               |> assign(:search_results, contacts)
               |> assign(:search_error, nil)
               |> assign(:using_cache, false)
               |> assign(:hubspot_credential, updated_credential)}

            {:error, reason} ->
              error_message = format_error(reason)
              {:noreply,
               socket
               |> assign(:search_results, [])
               |> assign(:search_error, error_message)
               |> assign(:using_cache, false)}
          end

        {:error, reason} ->
          error_message = "Failed to refresh token: #{inspect(reason)}"
          {:noreply,
           socket
           |> assign(:search_results, [])
           |> assign(:search_error, error_message)
           |> assign(:using_cache, false)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_contact", params, socket) do
    require Logger
    contact_id = Map.get(params, "contact-id") || Map.get(params, "contact_id")
    Logger.debug("Select contact event triggered with params: #{inspect(params)}, contact_id: #{inspect(contact_id)}")

    if socket.assigns.hubspot_connected && contact_id do
      # Immediately show loading state and return
      socket =
        socket
        |> assign(:selected_contact, nil)
        |> assign(:loading_contact, true)
        |> assign(:search_error, nil)
        |> assign(:search_results, nil)

      # Do the heavy work asynchronously
      parent_pid = self()
      component_id = socket.assigns.myself
      user_id = socket.assigns.current_user.id
      meeting_id = socket.assigns.meeting.id
      credential = socket.assigns.hubspot_credential

      Task.start(fn ->
        try do
          # Always fetch fresh from HubSpot API (don't use cache)
          case Accounts.ensure_valid_hubspot_token(credential) do
            {:ok, valid_token} ->
              case HubspotApi.get_contact(valid_token, contact_id) do
                {:ok, contact} ->
                  # Update the cache with fresh data
                  HubspotContactCache.cache_contact(user_id, contact.id, contact.properties)

                  Logger.debug("Contact fetched and cached: #{contact.id}")

                  # Reload credential in case token was refreshed
                  updated_credential = Accounts.get_user_credential!(credential.id)

                  # Check for cached suggestions first
                  cached_suggestions = HubspotSuggestions.get_cached_suggestions(meeting_id, contact.id)

                  # Send message to parent LiveView to update component
                  send(parent_pid, {:contact_loaded, component_id, contact, updated_credential, cached_suggestions})

                {:error, reason} ->
                  Logger.error("Failed to fetch contact from HubSpot: #{inspect(reason)}")
                  send(parent_pid, {:contact_load_error, component_id, "Failed to fetch contact details"})
              end

            {:error, reason} ->
              Logger.error("Failed to validate HubSpot token: #{inspect(reason)}")
              send(parent_pid, {:contact_load_error, component_id, "Failed to validate HubSpot token"})
          end
        rescue
          e ->
            Logger.error("Error loading contact: #{Exception.format(:error, e, __STACKTRACE__)}")
            send(parent_pid, {:contact_load_error, component_id, "An error occurred while loading the contact"})
        end
      end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_suggested_value", params, socket) do
    field_str = Map.get(params, "field")
    field_atom = String.to_atom(field_str)

    # Get the value from the input field
    new_value = Map.get(params, "suggested_value", "")

    current_edited = socket.assigns.edited_suggestions

    # Store the edited value
    new_edited = Map.put(current_edited, field_atom, new_value)

    {:noreply, assign(socket, :edited_suggestions, new_edited)}
  end

  @impl true
  def handle_event("show_evidence_tooltip", %{"field" => field}, socket) do
    # Find the suggestion with this field
    suggestion = Enum.find(socket.assigns.suggestions, fn s -> to_string(s.field) == field end)

    tooltip_text = if suggestion && suggestion.evidence, do: suggestion.evidence, else: ""

    # Toggle tooltip visibility for this field
    current_tooltips = socket.assigns[:evidence_tooltips] || %{}
    field_atom = String.to_atom(field)

    new_tooltips =
      if Map.has_key?(current_tooltips, field_atom) do
        Map.delete(current_tooltips, field_atom)
      else
        Map.put(current_tooltips, field_atom, tooltip_text)
      end

    {:noreply, assign(socket, :evidence_tooltips, new_tooltips)}
  end

  @impl true
  def handle_event("toggle_field_editable", %{"field" => field}, socket) do
    field_atom = String.to_atom(field)
    current_editable = socket.assigns.editable_fields

    new_editable =
      if Map.has_key?(current_editable, field_atom) do
        Map.delete(current_editable, field_atom)
      else
        Map.put(current_editable, field_atom, true)
      end

    {:noreply, assign(socket, :editable_fields, new_editable)}
  end

  @impl true
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

  @impl true
  def handle_event("toggle_category", %{"category" => category_key}, socket) do
    category = key_to_category(category_key)
    category_suggestions = get_suggestions_for_category(socket.assigns.suggestions, category)
    current_approved = socket.assigns.approved_suggestions

    # Check if all are selected
    all_selected =
      Enum.all?(category_suggestions, fn s -> Map.has_key?(current_approved, s.field) end)

    new_approved =
      if all_selected do
        # Deselect all in category
        Enum.reduce(category_suggestions, current_approved, fn s, acc ->
          Map.delete(acc, s.field)
        end)
      else
        # Select all in category
        Enum.reduce(category_suggestions, current_approved, fn s, acc ->
          Map.put(acc, s.field, true)
        end)
      end

    {:noreply, assign(socket, :approved_suggestions, new_approved)}
  end

  @impl true
  def handle_event("toggle_category_expand", %{"category" => category_key}, socket) do
    current_expanded = socket.assigns.expanded_categories
    new_expanded =
      if Map.get(current_expanded, category_key, true) do
        Map.put(current_expanded, category_key, false)
      else
        Map.put(current_expanded, category_key, true)
      end

    {:noreply, assign(socket, :expanded_categories, new_expanded)}
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    # Clear selected contact but keep suggestions visible
    # Reset current values in suggestions to nil since no contact is selected
    updated_suggestions =
      Enum.map(socket.assigns.suggestions, fn suggestion ->
        %{suggestion | current_value: nil}
      end)

    # Clear the search form field
    cleared_search_form = to_form(%{"query" => ""}, as: :search)

    {:noreply,
     socket
     |> assign(:selected_contact, nil)
     |> assign(:suggestions, updated_suggestions)
     |> assign(:approved_suggestions, %{})
     |> assign(:edited_suggestions, %{})
     |> assign(:editable_fields, %{})
     |> assign(:search_results, nil)
     |> assign(:search_form, cleared_search_form)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  @impl true
  def handle_event("refetch_suggestions", _params, socket) do
    if socket.assigns.selected_contact do
      # Delete cached suggestions and regenerate
      HubspotSuggestions.delete_suggestions(
        socket.assigns.meeting.id,
        socket.assigns.selected_contact.id
      )

      socket =
        socket
        |> assign(:suggestions, [])
        |> assign(:approved_suggestions, %{})
        |> assign(:edited_suggestions, %{})
        |> assign(:editable_fields, %{})
        |> assign(:loading_suggestions, true)
        |> assign(:suggestions_error, nil)
        |> assign(:using_cached_suggestions, false)

      # Send message to parent LiveView, which will forward to component
      send(self(), {:generate_suggestions_for_component, socket.assigns.selected_contact})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_hubspot", _params, socket) do
    if socket.assigns.hubspot_connected && socket.assigns.selected_contact do
      # Build properties map from approved suggestions
      # Use edited values if available, otherwise use original suggested_value
      properties =
        socket.assigns.suggestions
        |> Enum.filter(fn suggestion ->
          Map.has_key?(socket.assigns.approved_suggestions, suggestion.field)
        end)
        |> Enum.reduce(%{}, fn suggestion, acc ->
          field_name = Atom.to_string(suggestion.field)
          # Use edited value if it exists, otherwise use original suggested_value
          value = Map.get(socket.assigns.edited_suggestions, suggestion.field, suggestion.suggested_value)
          Map.put(acc, field_name, value)
        end)

      if map_size(properties) > 0 do
        case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
          {:ok, valid_token} ->
            case HubspotApi.update_contact(
                   valid_token,
                   socket.assigns.selected_contact.id,
                   properties
                 ) do
              {:ok, updated_contact} ->
                # Reload credential in case token was refreshed
                updated_credential = Accounts.get_user_credential!(
                  socket.assigns.hubspot_credential.id
                )

                # Update the local contact cache with the new properties
                HubspotContactCache.cache_contact(
                  socket.assigns.current_user.id,
                  updated_contact.id,
                  updated_contact.properties
                )

                # Update the selected_contact in socket with the fresh data
                # Merge the updated properties while preserving other fields
                updated_selected_contact = %{
                  socket.assigns.selected_contact
                  | properties: Map.merge(socket.assigns.selected_contact.properties, updated_contact.properties),
                    updated_at: updated_contact.updated_at
                }

                # Update suggestions with new current values from the updated contact
                updated_suggestions =
                  Enum.map(socket.assigns.suggestions, fn suggestion ->
                    field_str = Atom.to_string(suggestion.field)
                    current_value = Map.get(updated_selected_contact.properties, field_str)
                    %{suggestion | current_value: current_value}
                  end)

                {:noreply,
                 socket
                 |> assign(:update_success, true)
                 |> assign(:update_error, nil)
                 |> assign(:hubspot_credential, updated_credential)
                 |> assign(:selected_contact, updated_selected_contact)
                 |> assign(:suggestions, updated_suggestions)
                 |> assign(:approved_suggestions, %{})
                 |> assign(:edited_suggestions, %{})
                 |> assign(:editable_fields, %{})}

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

  def handle_info({:generate_suggestions, contact}, socket) do
    # Map contact properties to current values for suggestions
    current_values = contact.properties

    case HubspotAISuggestions.generate_suggestions(socket.assigns.meeting) do
      {:ok, suggestions} ->
        # Merge current values from HubSpot into suggestions
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
              "evidence" => suggestion.evidence,
              "timestamp" => suggestion.timestamp
            }
          end)

        HubspotSuggestions.save_suggestions(
          socket.assigns.meeting.id,
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

  defp contact_initials(contact) do
    first = contact.properties["firstname"] || ""
    last = contact.properties["lastname"] || ""
    email = contact.properties["email"] || ""

    cond do
      first != "" && last != "" ->
        String.first(String.upcase(first)) <> String.first(String.upcase(last))

      first != "" ->
        String.first(String.upcase(first)) <> String.first(String.upcase(first))

      email != "" ->
        String.first(String.upcase(email)) <> String.first(String.upcase(email))

      true ->
        "C"
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

  defp format_value(nil), do: ""
  defp format_value(""), do: ""
  defp format_value(value), do: to_string(value)

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

  defp group_suggestions_by_category(suggestions) do
    suggestions
    |> Enum.group_by(fn suggestion -> get_category_for_field(suggestion.field) end)
    |> Enum.sort_by(fn {category, _} -> category_order(category) end)
  end

  defp get_category_for_field(field) when field in [:firstname, :lastname], do: "Name"
  defp get_category_for_field(field) when field in [:email, :phone], do: "Contact Information"
  defp get_category_for_field(field) when field in [:company, :jobtitle], do: "Company"
  defp get_category_for_field(field) when field in [:address, :city, :state, :zip, :country], do: "Address"
  defp get_category_for_field(_field), do: "Other"

  defp category_order("Name"), do: 1
  defp category_order("Contact Information"), do: 2
  defp category_order("Company"), do: 3
  defp category_order("Address"), do: 4
  defp category_order(_), do: 5

  defp category_to_key("Name"), do: "name"
  defp category_to_key("Contact Information"), do: "contact_info"
  defp category_to_key("Company"), do: "company"
  defp category_to_key("Address"), do: "address"
  defp category_to_key(_), do: "other"

  defp key_to_category("name"), do: "Name"
  defp key_to_category("contact_info"), do: "Contact Information"
  defp key_to_category("company"), do: "Company"
  defp key_to_category("address"), do: "Address"
  defp key_to_category(_), do: "Other"

  defp get_suggestions_for_category(suggestions, category) do
    Enum.filter(suggestions, fn s -> get_category_for_field(s.field) == category end)
  end

  defp count_selected_in_category(category_suggestions, approved_suggestions) do
    Enum.count(category_suggestions, fn s -> Map.has_key?(approved_suggestions, s.field) end)
  end

  defp count_total_selected(suggestions, approved_suggestions) do
    Enum.count(suggestions, fn s -> Map.has_key?(approved_suggestions, s.field) end)
  end

  defp pluralize(1), do: ""
  defp pluralize(_), do: "s"

  defp pluralize_selected(1), do: ""
  defp pluralize_selected(_), do: "s"

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    # Parse timestamp in format like "(15:12)" or "15:12" or "15min, 12sec"
    # Pattern 1: Look for (MM:SS) or MM:SS format
    case Regex.run(~r/\(?(\d+):(\d+)\)?/, timestamp) do
      [_, minutes_str, seconds_str] ->
        {minutes, _} = Integer.parse(minutes_str)
        {seconds, _} = Integer.parse(seconds_str)
        format_time_minutes_seconds(minutes, seconds)
      nil ->
        # Pattern 2: Look for (MMmin, SSsec) format
        case Regex.run(~r/\((\d+)\s*(?:min|minutes?)[,\s]+(\d+)\s*(?:sec|seconds?)\)/i, timestamp) do
          [_, minutes_str, seconds_str] ->
            {minutes, _} = Integer.parse(minutes_str)
            {seconds, _} = Integer.parse(seconds_str)
            format_time_minutes_seconds(minutes, seconds)
          nil ->
            # If we can't parse it, return as-is
            timestamp
        end
    end
  end

  defp format_timestamp(_), do: nil

  defp format_time_minutes_seconds(minutes, seconds) do
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end
