defmodule TableauSocialExtension.Platform.RedditTest do
  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform.Reddit

  describe "label/0" do
    test "returns Reddit" do
      assert Reddit.label() == "Reddit"
    end
  end

  describe "keys/0" do
    test "returns expected keys" do
      assert Reddit.keys() == ["name", "type"]
    end
  end

  describe "url_builder/1" do
    test "builds user URL" do
      assert {:ok, "https://reddit.com/u/testuser"} = Reddit.url_builder(%{"type" => "user", "name" => "testuser"})
    end

    test "builds subreddit URL" do
      assert {:ok, "https://reddit.com/r/elixir"} = Reddit.url_builder(%{"type" => "subreddit", "name" => "elixir"})
    end

    test "returns error for invalid account" do
      assert {:error, "Invalid Reddit entry"} = Reddit.url_builder(%{"invalid" => "data"})
    end
  end

  describe "default_link_text/1" do
    test "returns user format" do
      assert {:ok, "u/testuser"} = Reddit.default_link_text(%{"type" => "user", "name" => "testuser"})
    end

    test "returns subreddit format" do
      assert {:ok, "r/elixir"} = Reddit.default_link_text(%{"type" => "subreddit", "name" => "elixir"})
    end

    test "returns error for invalid account" do
      assert {:error, "Invalid Reddit entry"} = Reddit.default_link_text(%{"invalid" => "data"})
    end
  end

  describe "parse_account/1" do
    test "returns error for empty string" do
      assert {:error, error_msg} = Reddit.parse_account("")
      assert error_msg =~ "Reddit entry format must be 'u/username' or 'r/subreddit'"
      assert error_msg =~ "got an empty string"
    end

    test "parses user account string" do
      assert {:ok, %{"type" => "user", "name" => "testuser"}} = Reddit.parse_account("u/testuser")
    end

    test "parses subreddit account string" do
      assert {:ok, %{"type" => "subreddit", "name" => "elixir"}} = Reddit.parse_account("r/elixir")
    end

    test "returns error for malformed string" do
      assert {:error, error_msg} = Reddit.parse_account("invalid")
      assert error_msg =~ "Reddit entry format must be 'u/username' or 'r/subreddit'"
      assert error_msg =~ "got: \"invalid\""
    end

    test "returns error for empty username" do
      assert {:error, error_msg} = Reddit.parse_account("u/")
      assert error_msg =~ "Reddit entry format must be 'u/username' or 'r/subreddit'"
    end

    test "returns error for empty subreddit" do
      assert {:error, error_msg} = Reddit.parse_account("r/")
      assert error_msg =~ "Reddit entry format must be 'u/username' or 'r/subreddit'"
    end

    test "parses valid user map with string keys" do
      account = %{"type" => "user", "name" => "testuser"}
      assert ^account = Reddit.parse_account(account)
    end

    test "parses valid subreddit map with string keys" do
      account = %{"type" => "subreddit", "name" => "elixir"}
      assert ^account = Reddit.parse_account(account)
    end

    test "parses valid user map with atom keys" do
      expected = %{"type" => "user", "name" => "testuser"}
      assert ^expected = Reddit.parse_account(%{type: "user", name: "testuser"})
    end

    test "parses valid subreddit map with atom keys" do
      expected = %{"type" => "subreddit", "name" => "elixir"}
      assert ^expected = Reddit.parse_account(%{type: "subreddit", name: "elixir"})
    end

    test "returns error for invalid map" do
      assert {:error, error_msg} = Reddit.parse_account(%{"invalid" => "data"})
      assert error_msg =~ "Reddit account maps must have a 'type' key"
    end

    test "returns error for invalid type" do
      assert {:error, error_msg} = Reddit.parse_account(%{"type" => "invalid", "name" => "test"})
      assert error_msg =~ "Reddit account maps must have a 'type' key"
    end

    test "returns error for empty name" do
      assert {:error, error_msg} = Reddit.parse_account(%{"type" => "user", "name" => ""})
      assert error_msg =~ "Reddit account maps must have a 'type' key"
    end
  end

  describe "filter_by_key/2" do
    setup do
      {:ok,
       accounts: [
         %{"type" => "user", "name" => "alice"},
         %{"type" => "subreddit", "name" => "elixir"},
         %{"type" => "user", "name" => "bob"}
       ]}
    end

    test "finds exact match with slash format", %{accounts: accounts} do
      assert {:ok, %{"type" => "user", "name" => "alice"}} =
               Reddit.filter_by_key(accounts, "u/alice")
    end

    test "finds by name only when unique", %{accounts: accounts} do
      assert {:ok, %{"type" => "subreddit", "name" => "elixir"}} =
               Reddit.filter_by_key(accounts, "elixir")
    end

    test "returns error when no match found by name" do
      assert {:error, "No Reddit entry found for name nonexistent"} =
               Reddit.filter_by_key([], "nonexistent")
    end

    test "returns error when multiple matches found by name", %{accounts: accounts} do
      accounts = accounts ++ [%{"type" => "user", "name" => "alice"}]

      assert {:error, "Multiple Reddit entries found for name alice"} =
               Reddit.filter_by_key(accounts, "alice")
    end

    test "returns new account when exact match not found in accounts" do
      assert {:ok, %{"type" => "user", "name" => "newuser"}} =
               Reddit.filter_by_key([], "u/newuser")
    end

    test "returns error for malformed slash format" do
      assert {:error, error_msg} = Reddit.filter_by_key([], "invalid/format")
      assert error_msg =~ "Reddit entry format must be 'u/username' or 'r/subreddit'"
    end
  end
end
