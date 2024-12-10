defmodule TableauSocialExtension.Platform.Reddit do
  @moduledoc """
  Handler for Reddit profiles and subreddits where entries can be specified as:

  - `u/{username}` (user profile)
  - `r/{subreddit}` (subreddit)

  This handler uses a url_builder function instead of a template because it needs to generate
  different URL patterns based on the type (user vs subreddit).
  """

  use TableauSocialExtension.Platform

  @impl Platform
  def label, do: "Reddit"

  @impl Platform
  def url_builder(%{"type" => "user", "name" => name}) do
    {:ok, "https://reddit.com/u/#{name}"}
  end

  def url_builder(%{"type" => "subreddit", "name" => name}) do
    {:ok, "https://reddit.com/r/#{name}"}
  end

  def url_builder(_) do
    {:error, "Invalid Reddit entry"}
  end

  @impl Platform
  def default_link_text(%{"type" => "user", "name" => name}) do
    {:ok, "u/#{name}"}
  end

  def default_link_text(%{"type" => "subreddit", "name" => name}) do
    {:ok, "r/#{name}"}
  end

  def default_link_text(_) do
    {:error, "Invalid Reddit entry"}
  end

  @impl Platform
  def keys, do: ["name", "type"]

  @impl Platform
  def parse_account("") do
    account_error("")
  end

  def parse_account(account) when is_binary(account) do
    case String.split(account, "/", parts: 2) do
      ["u", username] when username != "" ->
        {:ok, %{"type" => "user", "name" => username}}

      ["r", subreddit] when subreddit != "" ->
        {:ok, %{"type" => "subreddit", "name" => subreddit}}

      _ ->
        account_error(account)
    end
  end

  def parse_account(%{"type" => type, "name" => name})
      when type in ["user", "subreddit"] and is_binary(name) and byte_size(name) > 0 do
    %{"type" => type, "name" => name}
  end

  def parse_account(%{type: type, name: name})
      when type in ["user", "subreddit"] and is_binary(name) and byte_size(name) > 0 do
    %{"type" => type, "name" => name}
  end

  def parse_account(account) when is_map(account) do
    {:error, "Reddit account maps must have a 'type' key (either 'user' or 'subreddit') and a 'name' key"}
  end

  @impl Platform
  def filter_by_key(accounts, key) when is_binary(key) do
    if String.contains?(key, "/") do
      find_exact_match(accounts, key)
    else
      find_by_name(accounts, key)
    end
  end

  def filter_by_key(accounts, %{"type" => _type, "name" => _name} = key) do
    find_exact_match(accounts, key)
  end

  def filter_by_key(accounts, %{"name" => name}) do
    find_by_name(accounts, name)
  end

  def filter_by_key(_accounts, %{"type" => _}) do
    {:error, "Cannot filter Reddit links by type"}
  end

  defp find_exact_match(accounts, key) do
    case parse_account(key) do
      {:ok, account} ->
        case Enum.find(accounts, :error, &(account == &1)) do
          :error -> {:ok, account}
          result -> {:ok, result}
        end

      error ->
        error
    end
  end

  defp find_by_name(accounts, key) do
    case Enum.filter(accounts, &(&1["name"] == key)) do
      [] -> {:error, "No Reddit entry found for name #{key}"}
      [account] -> {:ok, account}
      _list -> {:error, "Multiple Reddit entries found for name #{key}"}
    end
  end

  defp account_error(value) do
    {:error, "Reddit entry format must be 'u/username' or 'r/subreddit', #{error_value(value)}"}
  end

  defp error_value("") do
    "got an empty string"
  end

  defp error_value(value) do
    "got: #{inspect(value)}"
  end
end
