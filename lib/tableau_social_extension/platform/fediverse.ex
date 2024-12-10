defmodule TableauSocialExtension.Platform.Fediverse do
  @moduledoc """
  Helper functions for Fediverse platform parsing, where accounts are generally
  represented as `@{username}@{instance}` and the URLs are formatted with some variation
  of `https://{instance}/@{user}`.
  """

  def default_link_text, do: "@{username}@{instance}"
  def url_template, do: "https://{instance}/@{username}"
  def keys, do: ["instance", "username"]

  def parse_account("", platform) do
    {:error, "#{platform} accounts must not be empty strings"}
  end

  def parse_account(account, platform) when is_binary(account) do
    case String.split(account, "@", parts: 2) do
      [user, instance] when instance != "" and user != "" ->
        if String.contains?(instance, "@") do
          account_error(account, platform)
        else
          {:ok, %{"username" => user, "instance" => instance}}
        end

      _ ->
        account_error(account, platform)
    end
  end

  def parse_account(%{"username" => username, "instance" => instance}, _platform) do
    {:ok, %{"username" => username, "instance" => instance}}
  end

  def parse_account(%{username: username, instance: instance}, _platform) do
    {:ok, %{"username" => username, "instance" => instance}}
  end

  def parse_account(account, platform) when is_map(account) do
    {:error, "#{platform} accounts must have username and instance keys"}
  end

  def parse_account(_, platform) do
    {:error, "#{platform} accounts must be strings or maps"}
  end

  def filter_by_key(accounts, %{"username" => _, "instance" => _} = key, platform) do
    find_exact_match(accounts, key, platform)
  end

  def filter_by_key(accounts, %{"username" => username}, platform) do
    find_by_key(accounts, "username", username, platform)
  end

  def filter_by_key(accounts, %{"instance" => instance}, platform) do
    find_by_key(accounts, "instance", instance, platform)
  end

  def filter_by_key(accounts, key, platform) do
    lookup_key = String.trim_leading(key, "@")

    cond do
      String.contains?(lookup_key, "@") ->
        find_exact_match(accounts, lookup_key, platform)

      String.contains?(lookup_key, ".") ->
        find_by_key(accounts, "instance", lookup_key, platform)

      true ->
        find_by_key(accounts, "username", lookup_key, platform)
    end
  end

  defp find_exact_match(accounts, target_account, platform) do
    case parse_account(target_account, platform) do
      {:ok, account} ->
        case Enum.find(accounts, :error, &(account == &1)) do
          :error -> {:ok, account}
          result -> {:ok, result}
        end

      error ->
        error
    end
  end

  defp find_by_key(accounts, key, value, platform) do
    case Enum.filter(accounts, &(&1[key] == value)) do
      [] -> {:error, "No #{platform} account found for #{key} #{value}"}
      [account] -> {:ok, account}
      _list -> {:error, "Multiple #{platform} accounts found for #{key} #{value}"}
    end
  end

  defp account_error(value, platform) do
    {:error, "#{platform} account format must be 'user@instance', #{error_value(value)}"}
  end

  defp error_value("") do
    "got an empty string"
  end

  defp error_value(value) do
    "got: #{inspect(value)}"
  end
end
