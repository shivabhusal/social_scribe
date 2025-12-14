defmodule SocialScribe.HubspotContactCacheTest do
  use SocialScribe.DataCase

  alias SocialScribe.HubspotContactCache
  alias SocialScribe.Hubspot.HubspotContactCache, as: CacheSchema

  import SocialScribe.HubspotFixtures
  import SocialScribe.AccountsFixtures

  describe "search_cached_contacts/2" do
    test "returns empty list when query is less than 3 characters" do
      user = user_fixture()
      assert HubspotContactCache.search_cached_contacts(user.id, "ab") == []
      assert HubspotContactCache.search_cached_contacts(user.id, "") == []
    end

    test "returns empty list when no contacts match" do
      user = user_fixture()
      assert HubspotContactCache.search_cached_contacts(user.id, "nonexistent") == []
    end

    test "searches contacts by firstname" do
      user = user_fixture()
      hubspot_contact_cache_fixture(%{
        user_id: user.id,
        properties: %{
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john@example.com"
        }
      })

      results = HubspotContactCache.search_cached_contacts(user.id, "john")
      assert length(results) == 1
      assert hd(results).properties["firstname"] == "John"
    end

    test "searches contacts by lastname" do
      user = user_fixture()
      hubspot_contact_cache_fixture(%{
        user_id: user.id,
        properties: %{
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john@example.com"
        }
      })

      results = HubspotContactCache.search_cached_contacts(user.id, "doe")
      assert length(results) == 1
      assert hd(results).properties["lastname"] == "Doe"
    end

    test "searches contacts by email" do
      user = user_fixture()
      hubspot_contact_cache_fixture(%{
        user_id: user.id,
        properties: %{
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john.doe@example.com"
        }
      })

      results = HubspotContactCache.search_cached_contacts(user.id, "john.doe")
      assert length(results) == 1
      assert hd(results).properties["email"] == "john.doe@example.com"
    end

    test "case insensitive search" do
      user = user_fixture()
      hubspot_contact_cache_fixture(%{
        user_id: user.id,
        properties: %{
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john@example.com"
        }
      })

      results = HubspotContactCache.search_cached_contacts(user.id, "JOHN")
      assert length(results) == 1
    end

    test "only returns contacts for the specified user" do
      user1 = user_fixture()
      user2 = user_fixture()

      hubspot_contact_cache_fixture(%{
        user_id: user1.id,
        properties: %{"firstname" => "John", "email" => "john@example.com"}
      })

      hubspot_contact_cache_fixture(%{
        user_id: user2.id,
        properties: %{"firstname" => "Jane", "email" => "jane@example.com"}
      })

      results = HubspotContactCache.search_cached_contacts(user1.id, "john")
      assert length(results) == 1
      assert hd(results).properties["firstname"] == "John"
    end

    test "limits results to 10" do
      user = user_fixture()

      for i <- 1..15 do
        hubspot_contact_cache_fixture(%{
          user_id: user.id,
          properties: %{
            "firstname" => "User#{i}",
            "email" => "user#{i}@example.com"
          }
        })
      end

      results = HubspotContactCache.search_cached_contacts(user.id, "user")
      assert length(results) == 10
    end

    test "excludes expired cache entries" do
      user = user_fixture()
      contact_id = "contact_123"

      # Create an expired cache entry
      expired_time = DateTime.add(DateTime.utc_now(), -25 * 3600, :second)
      {:ok, _} =
        %CacheSchema{}
        |> CacheSchema.changeset(%{
          user_id: user.id,
          hubspot_contact_id: contact_id,
          properties: %{"firstname" => "Expired", "email" => "expired@example.com"},
          cached_at: expired_time
        })
        |> SocialScribe.Repo.insert()

      # Create a fresh cache entry
      hubspot_contact_cache_fixture(%{
        user_id: user.id,
        hubspot_contact_id: "contact_456",
        properties: %{"firstname" => "Fresh", "email" => "fresh@example.com"}
      })

      results = HubspotContactCache.search_cached_contacts(user.id, "fresh")
      assert length(results) == 1
      assert hd(results).properties["firstname"] == "Fresh"
    end
  end

  describe "get_cached_contact/2" do
    test "returns nil when contact doesn't exist" do
      user = user_fixture()
      assert HubspotContactCache.get_cached_contact(user.id, "nonexistent") == nil
    end

    test "returns cached contact when it exists and is not expired" do
      user = user_fixture()
      cached = hubspot_contact_cache_fixture(%{user_id: user.id})

      result = HubspotContactCache.get_cached_contact(user.id, cached.hubspot_contact_id)
      assert result != nil
      assert result.hubspot_contact_id == cached.hubspot_contact_id
    end

    test "returns nil for expired cache" do
      user = user_fixture()
      contact_id = "contact_123"

      expired_time = DateTime.add(DateTime.utc_now(), -25 * 3600, :second)
      {:ok, _} =
        %CacheSchema{}
        |> CacheSchema.changeset(%{
          user_id: user.id,
          hubspot_contact_id: contact_id,
          properties: %{"firstname" => "Expired"},
          cached_at: expired_time
        })
        |> SocialScribe.Repo.insert()

      assert HubspotContactCache.get_cached_contact(user.id, contact_id) == nil
    end
  end

  describe "cache_contact/3" do
    test "creates new cache entry when none exists" do
      user = user_fixture()
      contact_id = "contact_123"
      properties = %{
        "firstname" => "John",
        "email" => "john@example.com"
      }

      assert {:ok, %CacheSchema{} = cached} =
               HubspotContactCache.cache_contact(user.id, contact_id, properties)

      assert cached.hubspot_contact_id == contact_id
      assert cached.user_id == user.id
      assert cached.properties == properties
      assert cached.cached_at != nil
    end

    test "updates existing cache entry" do
      user = user_fixture()
      cached = hubspot_contact_cache_fixture(%{user_id: user.id})

      new_properties = %{
        "firstname" => "Updated",
        "email" => "updated@example.com"
      }

      assert {:ok, %CacheSchema{} = updated} =
               HubspotContactCache.cache_contact(user.id, cached.hubspot_contact_id, new_properties)

      assert updated.id == cached.id
      assert updated.properties == new_properties
      assert DateTime.compare(updated.cached_at, cached.cached_at) != :lt
    end

    test "validates required fields" do
      # Test validation by creating invalid changeset directly
      changeset = CacheSchema.changeset(%CacheSchema{}, %{})
      refute changeset.valid?
      assert %{hubspot_contact_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_cached_contact/2" do
    test "returns ok when contact doesn't exist" do
      user = user_fixture()
      assert {:ok, nil} = HubspotContactCache.delete_cached_contact(user.id, "nonexistent")
    end

    test "deletes existing cached contact" do
      user = user_fixture()
      cached = hubspot_contact_cache_fixture(%{user_id: user.id})

      assert {:ok, %CacheSchema{}} =
               HubspotContactCache.delete_cached_contact(user.id, cached.hubspot_contact_id)

      assert HubspotContactCache.get_cached_contact(user.id, cached.hubspot_contact_id) == nil
    end
  end

  describe "cleanup_expired_cache/0" do
    test "deletes expired cache entries" do
      user = user_fixture()

      # Create expired entry
      expired_time = DateTime.add(DateTime.utc_now(), -25 * 3600, :second)
      {:ok, expired} =
        %CacheSchema{}
        |> CacheSchema.changeset(%{
          user_id: user.id,
          hubspot_contact_id: "expired_123",
          properties: %{"firstname" => "Expired"},
          cached_at: expired_time
        })
        |> SocialScribe.Repo.insert()

      # Create fresh entry
      fresh = hubspot_contact_cache_fixture(%{user_id: user.id})

      {deleted_count, _} = HubspotContactCache.cleanup_expired_cache()

      assert deleted_count >= 1
      assert HubspotContactCache.get_cached_contact(user.id, expired.hubspot_contact_id) == nil
      assert HubspotContactCache.get_cached_contact(user.id, fresh.hubspot_contact_id) != nil
    end
  end
end
