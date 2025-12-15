defmodule SocialScribe.Workers.HubSpotTokenRefresher do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias SocialScribe.Accounts
  alias SocialScribe.Repo
  alias SocialScribe.Accounts.UserCredential

  import Ecto.Query

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    hubspot_credentials = get_hubspot_credentials()

    if Enum.any?(hubspot_credentials) do
      Logger.info("Refreshing tokens for #{Enum.count(hubspot_credentials)} HubSpot credentials...")
    end

    for credential <- hubspot_credentials do
      refresh_credential_token(credential)
    end

    :ok
  end

  defp get_hubspot_credentials do
    from(c in UserCredential, where: c.provider == "hubspot")
    |> Repo.all()
  end

  defp refresh_credential_token(credential) do
    case Accounts.ensure_valid_hubspot_token(credential) do
      {:ok, _token} ->
        Logger.debug("Successfully refreshed HubSpot token for credential #{credential.id}")

      {:error, {:refresh_failed, {_status, %{"status" => "BAD_REFRESH_TOKEN"} = error_body}}} ->
        Logger.warning(
          "HubSpot credential #{credential.id} has invalid refresh token (BAD_REFRESH_TOKEN). " <>
            "User needs to re-authenticate. Error: #{inspect(error_body)}"
        )

      {:error, {:refresh_failed, {status, error_body}}} when is_map(error_body) ->
        Logger.error(
          "Failed to refresh HubSpot token for credential #{credential.id}: " <>
            "status=#{status}, error=#{inspect(error_body)}"
        )

      {:error, reason} ->
        Logger.error(
          "Failed to refresh HubSpot token for credential #{credential.id}: #{inspect(reason)}"
        )
    end
  end
end
