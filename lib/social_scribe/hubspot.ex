defmodule SocialScribe.Hubspot do
  require Logger

  @behaviour SocialScribe.HubspotApi

  @hubspot_api_base_url "https://api.hubapi.com"

  @impl SocialScribe.HubspotApi
  def search_contacts(token, query) do
    search_contacts_with_token(token, query)
  end

  defp search_contacts_with_token(token, query, _retry \\ true) do
    url = "#{@hubspot_api_base_url}/crm/v3/objects/contacts/search"

    # HubSpot search: filterGroups are ORed, filters within a group are ANDed
    # Create separate filterGroups for each field to achieve OR behavior
    body = %{
      filterGroups: [
        %{
          filters: [
            %{
              propertyName: "firstname",
              operator: "CONTAINS_TOKEN",
              value: query
            }
          ]
        },
        %{
          filters: [
            %{
              propertyName: "lastname",
              operator: "CONTAINS_TOKEN",
              value: query
            }
          ]
        },
        %{
          filters: [
            %{
              propertyName: "email",
              operator: "CONTAINS_TOKEN",
              value: query
            }
          ]
        }
      ],
      limit: 10,
      properties: ["firstname", "lastname", "email", "phone", "company"]
    }

    case Tesla.post(client(token), url, body) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        contacts =
          response_body
          |> Map.get("results", [])
          |> Enum.map(fn contact ->
            %{
              id: contact["id"],
              properties: contact["properties"] || %{},
              created_at: contact["createdAt"],
              updated_at: contact["updatedAt"]
            }
          end)

        {:ok, contacts}

      {:ok, %Tesla.Env{status: 401, body: error_body}} ->
        Logger.warning("HubSpot API Error (Status: 401 - Token expired): #{inspect(error_body)}")
        {:error, {:api_error, 401, "Token expired", error_body}}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        message = get_in(error_body, ["message"]) || "Unknown API error"
        {:error, {:api_error, status, message, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  @impl SocialScribe.HubspotApi
  def get_contact(token, contact_id) do
    get_contact_with_token(token, contact_id)
  end

  defp get_contact_with_token(token, contact_id, _retry \\ true) do
    properties = [
      "firstname",
      "lastname",
      "email",
      "phone",
      "company",
      "jobtitle",
      "website",
      "address",
      "city",
      "state",
      "zip",
      "country"
    ]

    # Build query string for properties
    properties_param = Enum.join(properties, ",")
    url = "#{@hubspot_api_base_url}/crm/v3/objects/contacts/#{contact_id}"

    case Tesla.get(client(token), url, query: [properties: properties_param]) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        contact = %{
          id: response_body["id"],
          properties: response_body["properties"] || %{},
          created_at: response_body["createdAt"],
          updated_at: response_body["updatedAt"]
        }

        {:ok, contact}

      {:ok, %Tesla.Env{status: 401, body: error_body}} ->
        Logger.warning("HubSpot API Error (Status: 401 - Token expired): #{inspect(error_body)}")
        {:error, {:api_error, 401, "Token expired", error_body}}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        message = get_in(error_body, ["message"]) || "Unknown API error"
        {:error, {:api_error, status, message, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  @impl SocialScribe.HubspotApi
  def update_contact(token, contact_id, properties) do
    update_contact_with_token(token, contact_id, properties)
  end

  defp update_contact_with_token(token, contact_id, properties, _retry \\ true) do
    url = "#{@hubspot_api_base_url}/crm/v3/objects/contacts/#{contact_id}"

    body = %{properties: properties}

    case Tesla.patch(client(token), url, body) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        contact = %{
          id: response_body["id"],
          properties: response_body["properties"] || %{},
          updated_at: response_body["updatedAt"]
        }

        Logger.info("Successfully updated HubSpot contact #{contact_id}")
        {:ok, contact}

      {:ok, %Tesla.Env{status: 401, body: error_body}} ->
        Logger.warning("HubSpot API Error (Status: 401 - Token expired): #{inspect(error_body)}")
        {:error, {:api_error, 401, "Token expired", error_body}}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        message = get_in(error_body, ["message"]) || "Unknown API error"
        {:error, {:api_error, status, message, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  defp client(token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @hubspot_api_base_url},
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{token}"},
         {"Content-Type", "application/json"}
       ]},
      Tesla.Middleware.JSON
    ])
  end
end
