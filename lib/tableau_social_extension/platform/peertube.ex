defmodule TableauSocialExtension.Platform.PeerTube do
  @moduledoc """
  Handler for PeerTube federated video platforms.

  This handler uses `TableauSocialExtension.Platform.Fediverse` for parsing
  `user@instance` accounts. URLs use the format `https://instance/c/username`.

  All parsing and filtering is delegated to the Fediverse module.
  """

  use TableauSocialExtension.Platform

  alias TableauSocialExtension.Platform.Fediverse

  @impl Platform
  def label, do: "PeerTube"

  @impl Platform
  def url_template, do: "https://{instance}/c/{username}"

  @impl Platform
  defdelegate keys, to: Fediverse

  @impl Platform
  defdelegate default_link_text, to: Fediverse

  @impl Platform
  def parse_account(account) do
    Fediverse.parse_account(account, label())
  end

  @impl Platform
  def filter_by_key(accounts, key) do
    Fediverse.filter_by_key(accounts, key, label())
  end
end
