defmodule SocialScribe.HubspotContactCache do
  @moduledoc """
  The HubspotContactCache context for managing cached HubSpot contacts.
  """

  import Ecto.Query, warn: false
  alias SocialScribe.Repo
  alias SocialScribe.Hubspot.HubspotContactCache

  # Cache expires after 24 hours
  @cache_ttl_hours 24

  @doc """
  Searches cached contacts by query (searches in firstname, lastname, email).
  Only returns contacts cached within the TTL period.
  """
  def search_cached_contacts(user_id, query) when byte_size(query) >= 3 do
    query_lower = String.downcase(query)
    cutoff_time = DateTime.utc_now() |> DateTime.add(-@cache_ttl_hours * 3600, :second)

    from(c in HubspotContactCache,
      where: c.user_id == ^user_id,
      where: c.cached_at >= ^cutoff_time,
      where:
        fragment(
          "LOWER(?) LIKE ? OR LOWER(?) LIKE ? OR LOWER(?) LIKE ?",
          fragment("?->>'firstname'", c.properties),
          ^"%#{query_lower}%",
          fragment("?->>'lastname'", c.properties),
          ^"%#{query_lower}%",
          fragment("?->>'email'", c.properties),
          ^"%#{query_lower}%"
        ),
      order_by: [desc: c.cached_at],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn cached ->
      %{
        id: cached.hubspot_contact_id,
        properties: cached.properties,
        created_at: cached.properties["createdate"],
        updated_at: cached.properties["lastmodifieddate"]
      }
    end)
  end

  def search_cached_contacts(_user_id, _query), do: []

  @doc """
  Gets a cached contact by HubSpot contact ID.
  Only returns if the cache is still valid (within TTL period).
  """
  def get_cached_contact(user_id, hubspot_contact_id) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-@cache_ttl_hours * 3600, :second)

    from(c in HubspotContactCache,
      where: c.user_id == ^user_id,
      where: c.hubspot_contact_id == ^hubspot_contact_id,
      where: c.cached_at >= ^cutoff_time,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates or updates a cached contact.
  """
  def cache_contact(user_id, hubspot_contact_id, properties) do
    attrs = %{
      hubspot_contact_id: hubspot_contact_id,
      properties: properties,
      user_id: user_id,
      cached_at: DateTime.utc_now()
    }

    case Repo.get_by(HubspotContactCache,
           user_id: user_id,
           hubspot_contact_id: hubspot_contact_id
         ) do
      nil ->
        %HubspotContactCache{}
        |> HubspotContactCache.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> HubspotContactCache.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a cached contact.
  """
  def delete_cached_contact(user_id, hubspot_contact_id) do
    case Repo.get_by(HubspotContactCache,
           user_id: user_id,
           hubspot_contact_id: hubspot_contact_id
         ) do
      nil -> {:ok, nil}
      cached -> Repo.delete(cached)
    end
  end

  @doc """
  Cleans up expired cache entries (older than TTL).
  """
  def cleanup_expired_cache do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-@cache_ttl_hours * 3600, :second)

    from(c in HubspotContactCache, where: c.cached_at < ^cutoff_time)
    |> Repo.delete_all()
  end
end
