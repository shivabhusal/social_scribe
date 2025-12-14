defmodule SocialScribe.HubspotApi do
  @moduledoc """
  Behaviour for HubSpot API operations.
  """

  @callback search_contacts(token :: String.t(), query :: String.t()) ::
              {:ok, list()} | {:error, any()}

  @callback get_contact(token :: String.t(), contact_id :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback update_contact(token :: String.t(), contact_id :: String.t(), properties :: map()) ::
              {:ok, map()} | {:error, any()}

  def search_contacts(token, query) do
    impl().search_contacts(token, query)
  end

  def get_contact(token, contact_id) do
    impl().get_contact(token, contact_id)
  end

  def update_contact(token, contact_id, properties) do
    impl().update_contact(token, contact_id, properties)
  end

  defp impl do
    Application.get_env(:social_scribe, :hubspot_api, SocialScribe.Hubspot)
  end
end
