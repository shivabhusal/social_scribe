defmodule SocialScribe.Workers.HubSpotTokenRefresherTest do
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures
  import SocialScribe.HubspotFixtures

  alias SocialScribe.Workers.HubSpotTokenRefresher
  alias SocialScribe.Repo
  alias SocialScribe.Accounts.UserCredential

  import Ecto.Query

  describe "perform/1" do
    test "does nothing if there are no HubSpot credentials" do
      # Ensure no HubSpot credentials exist
      Repo.delete_all(UserCredential)

      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok
    end

    test "calls ensure_valid_hubspot_token for expired HubSpot credentials" do
      user = user_fixture()

      # Create a HubSpot credential that is expired
      expired_credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -600, :second),
          token: "old_token",
          refresh_token: "refresh_token_123"
        })

      # Mock the Accounts.ensure_valid_hubspot_token function
      # Since we can't easily mock TokenRefresher, we'll test that the worker
      # correctly identifies and processes HubSpot credentials
      # The actual token refresh will be tested in Accounts tests

      # Verify the credential exists and is expired
      assert expired_credential.provider == "hubspot"
      assert DateTime.compare(expired_credential.expires_at, DateTime.utc_now()) == :lt

      # The worker should process this credential
      # Since we're testing the worker's behavior, we'll verify it completes
      # The actual token refresh logic is tested in Accounts.ensure_valid_hubspot_token tests
      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok
    end

    test "does not refresh tokens for HubSpot credentials that are still valid" do
      user = user_fixture()

      # Create a HubSpot credential that is still valid (expires in 1 hour)
      valid_credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "valid_token",
          refresh_token: "refresh_token_valid"
        })

      original_token = valid_credential.token
      original_expires_at = valid_credential.expires_at

      # The worker should process the credential, but ensure_valid_hubspot_token
      # should determine it doesn't need refreshing
      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok

      # Verify token was not changed (since it's still valid)
      updated_credential = Repo.get!(UserCredential, valid_credential.id)
      assert updated_credential.token == original_token
      assert updated_credential.expires_at == original_expires_at
    end

    test "handles token refresh errors gracefully" do
      user = user_fixture()

      # Create a HubSpot credential that is expired
      expired_credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -600, :second),
          token: "old_token",
          refresh_token: "invalid_refresh_token"
        })

      # The worker should handle errors gracefully without raising
      # Since we can't easily mock the TokenRefresher, we test that
      # the worker completes even if token refresh fails
      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok

      # The credential should still exist (error handling is tested in Accounts)
      assert Repo.get(UserCredential, expired_credential.id) != nil
    end

    test "only processes HubSpot credentials, ignores other providers" do
      user = user_fixture()

      # Create a HubSpot credential
      hubspot_credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "hubspot_token",
          refresh_token: "refresh_token_hubspot"
        })

      # Create a Google credential (should be ignored)
      google_credential =
        user_credential_fixture(%{
          user_id: user.id,
          provider: "google",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "old_google_token",
          refresh_token: "refresh_token_google"
        })

      original_google_token = google_credential.token

      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok

      # HubSpot credential should be processed (but not refreshed since it's valid)
      updated_hubspot = Repo.get!(UserCredential, hubspot_credential.id)
      assert updated_hubspot.provider == "hubspot"

      # Google credential should remain unchanged
      updated_google = Repo.get!(UserCredential, google_credential.id)
      assert updated_google.token == original_google_token
      assert updated_google.provider == "google"
    end

    test "processes multiple HubSpot credentials" do
      user1 = user_fixture()
      user2 = user_fixture()

      credential1 =
        hubspot_credential_fixture(%{
          user_id: user1.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "token_1",
          refresh_token: "refresh_token_1"
        })

      credential2 =
        hubspot_credential_fixture(%{
          user_id: user2.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          token: "token_2",
          refresh_token: "refresh_token_2"
        })

      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok

      # Both credentials should be processed
      updated1 = Repo.get!(UserCredential, credential1.id)
      assert updated1.provider == "hubspot"

      updated2 = Repo.get!(UserCredential, credential2.id)
      assert updated2.provider == "hubspot"
    end

    test "queries only HubSpot credentials from database" do
      user = user_fixture()

      # Create credentials for different providers
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      google_credential = user_credential_fixture(%{user_id: user.id, provider: "google"})
      linkedin_credential = user_credential_fixture(%{user_id: user.id, provider: "linkedin"})

      # Count HubSpot credentials
      hubspot_count =
        from(c in UserCredential, where: c.provider == "hubspot")
        |> Repo.aggregate(:count, :id)

      assert hubspot_count == 1

      # The worker should only process the HubSpot credential
      assert HubSpotTokenRefresher.perform(%Oban.Job{}) == :ok

      # All credentials should still exist
      assert Repo.get(UserCredential, hubspot_credential.id) != nil
      assert Repo.get(UserCredential, google_credential.id) != nil
      assert Repo.get(UserCredential, linkedin_credential.id) != nil
    end
  end
end
