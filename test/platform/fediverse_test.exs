defmodule TableauSocialExtension.Platform.FediverseTest do
  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform.Fediverse

  describe "default_link_text/0" do
    test "returns expected template" do
      assert Fediverse.default_link_text() == "@{username}@{instance}"
    end
  end

  describe "url_template/0" do
    test "returns expected template" do
      assert Fediverse.url_template() == "https://{instance}/@{username}"
    end
  end

  describe "keys/0" do
    test "returns expected keys" do
      assert Fediverse.keys() == ["instance", "username"]
    end
  end

  describe "parse_account/2" do
    test "parses valid user@instance format" do
      assert {:ok, %{"username" => "user", "instance" => "mastodon.social"}} =
               Fediverse.parse_account("user@mastodon.social", "TestPlatform")
    end

    test "returns error for empty string" do
      assert {:error, "TestPlatform accounts must not be empty strings"} =
               Fediverse.parse_account("", "TestPlatform")
    end

    test "returns error for malformed account with multiple @" do
      assert {:error, error_msg} = Fediverse.parse_account("user@instance@extra", "TestPlatform")
      assert error_msg =~ "TestPlatform account format must be 'user@instance'"
    end

    test "returns error for account without @" do
      assert {:error, error_msg} = Fediverse.parse_account("justusername", "TestPlatform")
      assert error_msg =~ "TestPlatform account format must be 'user@instance'"
    end

    test "returns error for account with empty username" do
      assert {:error, error_msg} = Fediverse.parse_account("@instance.com", "TestPlatform")
      assert error_msg =~ "TestPlatform account format must be 'user@instance'"
    end

    test "returns error for account with empty instance" do
      assert {:error, error_msg} = Fediverse.parse_account("user@", "TestPlatform")
      assert error_msg =~ "TestPlatform account format must be 'user@instance'"
    end

    test "parses map with string keys" do
      account = %{"username" => "user", "instance" => "mastodon.social"}
      assert {:ok, ^account} = Fediverse.parse_account(account, "TestPlatform")
    end

    test "parses map with atom keys" do
      account = %{username: "user", instance: "mastodon.social"}
      expected = %{"username" => "user", "instance" => "mastodon.social"}
      assert {:ok, ^expected} = Fediverse.parse_account(account, "TestPlatform")
    end

    test "returns error for map missing required keys" do
      assert {:error, "TestPlatform accounts must have username and instance keys"} =
               Fediverse.parse_account(%{"username" => "user"}, "TestPlatform")
    end

    test "returns error for non-string, non-map input" do
      assert {:error, "TestPlatform accounts must be strings or maps"} =
               Fediverse.parse_account(123, "TestPlatform")
    end
  end

  describe "filter_by_key/3" do
    setup do
      {:ok,
       accounts: [
         %{"username" => "alice", "instance" => "mastodon.social"},
         %{"username" => "bob", "instance" => "pixelfed.social"},
         %{"username" => "alice", "instance" => "peertube.example"}
       ]}
    end

    test "finds exact match with full account map", %{accounts: accounts} do
      key = %{"username" => "alice", "instance" => "mastodon.social"}
      assert {:ok, ^key} = Fediverse.filter_by_key(accounts, key, "TestPlatform")
    end

    test "finds by username only", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixelfed.social"}} =
               Fediverse.filter_by_key(accounts, %{"username" => "bob"}, "TestPlatform")
    end

    test "finds by instance only", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixelfed.social"}} =
               Fediverse.filter_by_key(accounts, %{"instance" => "pixelfed.social"}, "TestPlatform")
    end

    test "returns error when multiple matches for username", %{accounts: accounts} do
      assert {:error, "Multiple TestPlatform accounts found for username alice"} =
               Fediverse.filter_by_key(accounts, %{"username" => "alice"}, "TestPlatform")
    end

    test "returns error when no matches for username", %{accounts: accounts} do
      assert {:error, "No TestPlatform account found for username charlie"} =
               Fediverse.filter_by_key(accounts, %{"username" => "charlie"}, "TestPlatform")
    end

    test "parses string key with @ as full account", %{accounts: accounts} do
      assert {:ok, %{"username" => "alice", "instance" => "mastodon.social"}} =
               Fediverse.filter_by_key(accounts, "alice@mastodon.social", "TestPlatform")
    end

    test "parses string key with . as instance", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixelfed.social"}} =
               Fediverse.filter_by_key(accounts, "pixelfed.social", "TestPlatform")
    end

    test "parses string key without @ or . as username", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixelfed.social"}} =
               Fediverse.filter_by_key(accounts, "bob", "TestPlatform")
    end

    test "strips leading @ from key", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixelfed.social"}} =
               Fediverse.filter_by_key(accounts, "@bob", "TestPlatform")
    end

    test "returns new account when exact match not found in accounts" do
      assert {:ok, %{"username" => "new", "instance" => "example.com"}} =
               Fediverse.filter_by_key([], "new@example.com", "TestPlatform")
    end

    test "returns error for malformed account string" do
      assert {:error, error_msg} = Fediverse.filter_by_key([], "malformed", "TestPlatform")
      assert error_msg =~ "No TestPlatform account found for username malformed"
    end
  end
end
