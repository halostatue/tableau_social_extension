defmodule TableauSocialExtension.Platform.Mastodon do
  @moduledoc """
  Handler for Mastodon federated social platforms.

  This handler uses `TableauSocialExtension.Platform.Fediverse` for parsing
  `user@instance` accounts and generating `https://instance/@user` URLs.

  All parsing, filtering, and URL generation is delegated to the Fediverse module.
  """

  use TableauSocialExtension.Platform

  alias TableauSocialExtension.Platform.Fediverse

  @impl Platform
  def label, do: "Mastodon"

  @impl Platform
  defdelegate keys, to: Fediverse

  @impl Platform
  defdelegate url_template, to: Fediverse

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
