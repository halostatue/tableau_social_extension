defmodule TableauSocialExtension.Platform.PeerTubeTest do
  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform.PeerTube

  describe "label/0" do
    test "returns PeerTube" do
      assert PeerTube.label() == "PeerTube"
    end
  end

  describe "url_template/0" do
    test "returns PeerTube-specific template" do
      assert PeerTube.url_template() == "https://{instance}/c/{username}"
    end
  end

  describe "keys/0" do
    test "delegates to Fediverse" do
      assert PeerTube.keys() == ["instance", "username"]
    end
  end

  describe "default_link_text/0" do
    test "delegates to Fediverse" do
      assert PeerTube.default_link_text() == "@{username}@{instance}"
    end
  end

  describe "parse_account/1" do
    test "parses valid user@instance format" do
      assert {:ok, %{"username" => "user", "instance" => "peertube.example"}} =
               PeerTube.parse_account("user@peertube.example")
    end

    test "returns error with PeerTube label for empty string" do
      assert {:error, "PeerTube accounts must not be empty strings"} =
               PeerTube.parse_account("")
    end

    test "returns error with PeerTube label for malformed account" do
      assert {:error, error_msg} = PeerTube.parse_account("invalid")
      assert error_msg =~ "PeerTube account format must be 'user@instance'"
    end

    test "parses map with string keys" do
      account = %{"username" => "user", "instance" => "peertube.example"}
      assert {:ok, ^account} = PeerTube.parse_account(account)
    end
  end

  describe "filter_by_key/2" do
    setup do
      {:ok,
       accounts: [
         %{"username" => "alice", "instance" => "peertube.example"},
         %{"username" => "bob", "instance" => "video.social"}
       ]}
    end

    test "finds by username", %{accounts: accounts} do
      assert {:ok, %{"username" => "alice", "instance" => "peertube.example"}} =
               PeerTube.filter_by_key(accounts, %{"username" => "alice"})
    end

    test "finds by instance", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "video.social"}} =
               PeerTube.filter_by_key(accounts, %{"instance" => "video.social"})
    end

    test "returns error with PeerTube label when not found" do
      assert {:error, "No PeerTube account found for username charlie"} =
               PeerTube.filter_by_key([], %{"username" => "charlie"})
    end
  end
end
