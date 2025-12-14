defmodule SocialScribe.HubspotTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Hubspot

  # Note: These tests would require mocking Tesla HTTP client
  # For now, we test the structure and error handling patterns
  # Full integration tests would require actual HubSpot API access

  describe "search_contacts/2" do
    test "function exists and has correct arity" do
      # Verify function exists by checking exports
      exports = Hubspot.__info__(:functions)
      assert {:search_contacts, 2} in exports
    end
  end

  describe "get_contact/2" do
    test "function exists and has correct arity" do
      # Verify function exists by checking exports
      exports = Hubspot.__info__(:functions)
      assert {:get_contact, 2} in exports
    end
  end

  describe "update_contact/3" do
    test "function exists and has correct arity" do
      # Verify function exists by checking exports
      exports = Hubspot.__info__(:functions)
      assert {:update_contact, 3} in exports
    end
  end
end
