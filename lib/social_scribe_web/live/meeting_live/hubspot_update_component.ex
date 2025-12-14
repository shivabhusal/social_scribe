defmodule SocialScribeWeb.MeetingLive.HubspotUpdateComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Accounts
  alias SocialScribe.HubspotApi
  alias SocialScribe.HubspotAISuggestions
  alias SocialScribe.HubspotSuggestions

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <.header>
        Update HubSpot Contact
        <:subtitle>Review AI-suggested CRM updates from this meeting transcript.</:subtitle>
      </.header>

      <%= if not @hubspot_connected do %>
        <div class="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-md">
          <p class="text-yellow-800">
            Please connect your HubSpot account in
            <.link
              href={~p"/dashboard/settings"}
              class="font-semibold underline"
            >
              Settings
            </.link>
            to use this feature.
          </p>
        </div>
      <% else %>
        <!-- Contact Search Section -->
        <div class="mt-6">
          <h3 class="text-lg font-semibold text-slate-700 mb-3">Select Contact</h3>
          <.simple_form
            for={@search_form}
            phx-target={@myself}
            phx-submit="search_contacts"
          >
            <.input
              field={@search_form[:query]}
              type="text"
              placeholder="Search by name or email..."
              phx-debounce="300"
            />
            <:actions>
              <.button type="submit" phx-disable-with="Searching...">Search</.button>
            </:actions>
          </.simple_form>

          <%= if @search_results do %>
            <div class="mt-4 space-y-2">
              <div
                :for={contact <- @search_results}
                class="p-3 border rounded-md cursor-pointer hover:bg-slate-50"
                phx-click="select_contact"
                phx-value-contact-id={contact.id}
                phx-target={@myself}
              >
                <div class="font-medium text-slate-700">
                  <%= contact_name(contact) %>
                </div>
                <div class="text-sm text-slate-500">
                  <%= contact.properties["email"] || "No email" %>
                </div>
              </div>
            </div>
          <% end %>

          <%= if @search_error do %>
            <div class="mt-4 p-3 bg-red-50 border border-red-200 rounded-md text-red-800">
              {@search_error}
            </div>
          <% end %>
        </div>

        <!-- Selected Contact and Suggestions -->
        <%= if @selected_contact do %>
          <div class="mt-6 p-4 bg-slate-50 rounded-md">
            <h3 class="text-lg font-semibold text-slate-700 mb-2">Selected Contact</h3>
            <p class="text-slate-700">
              <strong>{contact_name(@selected_contact)}</strong>
              <%= if @selected_contact.properties["email"] do %>
                <span class="text-slate-500"> - {@selected_contact.properties["email"]}</span>
              <% end %>
            </p>
          </div>

          <%= if @loading_suggestions do %>
            <div class="mt-6 p-4 text-center">
              <p class="text-slate-600">Generating AI suggestions...</p>
            </div>
          <% else %>
            <%= if @suggestions_error do %>
              <div class="mt-6 p-4 bg-red-50 border border-red-200 rounded-md text-red-800">
                {@suggestions_error}
              </div>
            <% else %>
              <%= if Enum.empty?(@suggestions) do %>
                <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-md text-blue-800">
                  No updates suggested. The transcript doesn't contain explicit information that would update this contact.
                </div>
              <% else %>
                <!-- Suggestions Review Section -->
                <div class="mt-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-slate-700">Suggested Updates</h3>
                    <div class="flex items-center gap-3">
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
                  </div>
                  <div class="space-y-4">
                    <div
                      :for={suggestion <- @suggestions}
                      class="p-4 border rounded-md"
                    >
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <div class="font-medium text-slate-700 mb-2">
                            {format_field_name(suggestion.field)}
                          </div>
                          <div class="text-sm text-slate-600 mb-1">
                            <strong>Current:</strong> {format_value(suggestion.current_value)}
                          </div>
                          <div class="text-sm text-slate-600 mb-2">
                            <strong>Suggested:</strong> {format_value(suggestion.suggested_value)}
                          </div>
                          <%= if suggestion.evidence && suggestion.evidence != "" do %>
                            <div class="text-xs text-slate-500 italic mt-2">
                              Evidence: "{suggestion.evidence}"
                            </div>
                          <% end %>
                        </div>
                        <label class="relative inline-flex items-center cursor-pointer ml-4">
                          <input
                            type="checkbox"
                            class="sr-only peer"
                            checked={Map.get(@approved_suggestions, suggestion.field, false)}
                            phx-click="toggle_suggestion"
                            phx-value-field={suggestion.field}
                            phx-target={@myself}
                          />
                          <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600">
                          </div>
                        </label>
                      </div>
                    </div>
                  </div>

                  <!-- Update Button -->
                  <div class="mt-6 flex justify-end">
                    <.button
                      phx-click="update_hubspot"
                      phx-target={@myself}
                      phx-disable-with="Updating..."
                      disabled={Enum.empty?(@approved_suggestions)}
                      class="disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Update HubSpot
                    </.button>
                  </div>
                </div>
              <% end %>
            <% end %>
          <% end %>
        <% end %>

        <!-- Success/Error Messages -->
        <%= if @update_success do %>
          <div class="mt-6 p-4 bg-green-50 border border-green-200 rounded-md text-green-800">
            Contact updated successfully!
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
      |> assign_new(:search_form, fn -> to_form(%{"query" => ""}) end)
      |> assign_new(:search_results, fn -> nil end)
      |> assign_new(:search_error, fn -> nil end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading_suggestions, fn -> false end)
      |> assign_new(:suggestions_error, fn -> nil end)
      |> assign_new(:approved_suggestions, fn -> %{} end)
      |> assign_new(:update_success, fn -> false end)
      |> assign_new(:update_error, fn -> nil end)
      |> assign_new(:using_cached_suggestions, fn -> false end)

    # Always update hubspot_credential (it might change)
    hubspot_credential =
      Accounts.get_user_credential(socket.assigns.current_user, "hubspot")

    socket =
      socket
      |> assign(:hubspot_connected, not is_nil(hubspot_credential))
      |> assign(:hubspot_credential, hubspot_credential)

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
  def handle_event("search_contacts", %{"query" => query}, socket) do
    if socket.assigns.hubspot_connected && query != "" do
      case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
        {:ok, valid_token} ->
          case HubspotApi.search_contacts(valid_token, query) do
            {:ok, contacts} ->
              # Reload credential in case token was refreshed
              updated_credential = Accounts.get_user_credential!(
                socket.assigns.hubspot_credential.id
              )

              {:noreply,
               socket
               |> assign(:search_results, contacts)
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

  @impl true
  def handle_event("select_contact", %{"contact-id" => contact_id}, socket) do
    if socket.assigns.hubspot_connected do
      case Accounts.ensure_valid_hubspot_token(socket.assigns.hubspot_credential) do
        {:ok, valid_token} ->
          case HubspotApi.get_contact(valid_token, contact_id) do
            {:ok, contact} ->
              # Reload credential in case token was refreshed
              updated_credential = Accounts.get_user_credential!(
                socket.assigns.hubspot_credential.id
              )

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

              # Check for cached suggestions first
              case HubspotSuggestions.get_cached_suggestions(
                     socket.assigns.meeting.id,
                     contact.id
                   ) do
                nil ->
                  # No cache, generate suggestions asynchronously
                  # Send message to parent LiveView, which will forward to component
                  send(self(), {:generate_suggestions_for_component, contact})
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
                   |> assign(:suggestions, suggestions_with_current)
                   |> assign(:loading_suggestions, false)
                   |> assign(:suggestions_error, nil)
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
  def handle_event("update_hubspot", _params, socket) do
    if socket.assigns.hubspot_connected && socket.assigns.selected_contact do
      # Build properties map from approved suggestions
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
                # Reload credential in case token was refreshed
                updated_credential = Accounts.get_user_credential!(
                  socket.assigns.hubspot_credential.id
                )

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
              "evidence" => suggestion.evidence
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
end
