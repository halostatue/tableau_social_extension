defmodule TableauSocialExtension.Platform.StackOverflow do
  @moduledoc """
  Handler for Stack Overflow profiles where accounts can be specified as:

  - `{id}` (ID only, required for URL generation)
  - `{id}/{username}` (ID with optional username for display)

  The ID is required for URL generation, while the username is optional but highly
  recommended for display purposes.
  """

  use TableauSocialExtension.Platform

  @impl Platform
  def label, do: "Stack Overflow"

  @impl Platform
  def url_builder(%{"id" => id, "username" => username}) do
    {:ok, "https://stackoverflow.com/users/#{id}/#{username}"}
  end

  def url_builder(%{"id" => id}) do
    {:ok, "https://stackoverflow.com/users/#{id}"}
  end

  def url_builder(_) do
    {:error, "Invalid Stack Overflow account"}
  end

  @impl Platform
  def default_link_text(%{"username" => username}) do
    {:ok, username}
  end

  def default_link_text(%{"id" => id}) do
    {:ok, id}
  end

  def default_link_text(_) do
    {:error, "Invalid Stack Overflow account"}
  end

  @impl Platform
  def keys, do: ["id", "username"]

  @impl Platform
  def parse_account("") do
    account_error("")
  end

  def parse_account(account) when is_binary(account) do
    case Regex.named_captures(~r{(?<id>\d+)(?:/(?<username>[^/]+))?/?}, account) do
      %{"id" => id, "username" => username} ->
        build_account(id, username)

      _ ->
        account_error(account)
    end
  end

  def parse_account(%{"id" => id, "username" => username}) do
    build_account(id, username)
  end

  def parse_account(%{"id" => id}) do
    build_account(id)
  end

  def parse_account(%{id: id, username: username}) do
    build_account(id, username)
  end

  def parse_account(%{id: id}) do
    build_account(id)
  end

  def parse_account(account) when is_map(account) do
    {:error, "Stack Overflow accounts must have a 'id' positive integer value and should have a 'username' value"}
  end

  @impl Platform
  def filter_by_key(accounts, key) when is_binary(key) do
    if String.contains?(key, "/") do
      find_exact_match(accounts, key)
    else
      find_by_id(accounts, key)
    end
  end

  def filter_by_key(accounts, %{"id" => _, "username" => _} = key) do
    find_exact_match(accounts, key)
  end

  def filter_by_key(accounts, %{"id" => id}) do
    find_by_id(accounts, id)
  end

  def filter_by_key(accounts, %{"username" => username}) do
    find_by_username(accounts, username)
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

  defp find_by_id(accounts, id) do
    case valid_id(id) do
      {:ok, id} ->
        case Enum.filter(accounts, &(&1["id"] == id)) do
          [] -> {:error, "No Stack Overflow account found for id #{id}"}
          [account] -> {:ok, account}
          _list -> {:error, "Multiple Stack Overflow accounts found for id #{id}"}
        end

      error ->
        error
    end
  end

  defp find_by_username(accounts, username) do
    case Enum.filter(accounts, &(&1["username"] == username)) do
      [] -> {:error, "No Stack Overflow account found for username #{username}"}
      [account] -> {:ok, account}
      _list -> {:error, "Multiple Stack Overflow accounts found for username #{username}"}
    end
  end

  defp build_account(id) do
    case valid_id(id) do
      {:ok, id} -> {:ok, %{"id" => id}}
      error -> error
    end
  end

  defp build_account(id, username) when username in [nil, ""] do
    build_account(id)
  end

  defp build_account(id, username) do
    case valid_id(id) do
      {:ok, id} ->
        {:ok, %{"id" => id, "username" => username}}

      error ->
        error
    end
  end

  defp valid_id(id) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  defp valid_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, "Invalid Stack Overflow 'id' (must be positive integer)"}
    end
  end

  defp valid_id(_) do
    {:error, "Invalid Stack Overflow 'id'"}
  end

  defp account_error(value) do
    {:error, "Stack Overflow account format must be 'id' or 'id/username', #{error_value(value)}"}
  end

  defp error_value("") do
    "got an empty string"
  end

  defp error_value(value) do
    "got: #{inspect(value)}"
  end
end
