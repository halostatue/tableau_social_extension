defmodule TableauSocialExtension.Platform.PixelfedTest do
  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform.Pixelfed

  describe "label/0" do
    test "returns Pixelfed" do
      assert Pixelfed.label() == "Pixelfed"
    end
  end

  describe "url_template/0" do
    test "delegates to Fediverse" do
      assert Pixelfed.url_template() == "https://{instance}/@{username}"
    end
  end

  describe "keys/0" do
    test "delegates to Fediverse" do
      assert Pixelfed.keys() == ["instance", "username"]
    end
  end

  describe "default_link_text/0" do
    test "delegates to Fediverse" do
      assert Pixelfed.default_link_text() == "@{username}@{instance}"
    end
  end

  describe "parse_account/1" do
    test "parses valid user@instance format" do
      assert {:ok, %{"username" => "user", "instance" => "pixelfed.social"}} =
               Pixelfed.parse_account("user@pixelfed.social")
    end

    test "returns error with Pixelfed label for empty string" do
      assert {:error, "Pixelfed accounts must not be empty strings"} =
               Pixelfed.parse_account("")
    end

    test "returns error with Pixelfed label for malformed account" do
      assert {:error, error_msg} = Pixelfed.parse_account("invalid")
      assert error_msg =~ "Pixelfed account format must be 'user@instance'"
    end

    test "parses map with string keys" do
      account = %{"username" => "user", "instance" => "pixelfed.social"}
      assert {:ok, ^account} = Pixelfed.parse_account(account)
    end
  end

  describe "filter_by_key/2" do
    setup do
      {:ok,
       accounts: [
         %{"username" => "alice", "instance" => "pixelfed.social"},
         %{"username" => "bob", "instance" => "pixel.example"}
       ]}
    end

    test "finds by username", %{accounts: accounts} do
      assert {:ok, %{"username" => "alice", "instance" => "pixelfed.social"}} =
               Pixelfed.filter_by_key(accounts, %{"username" => "alice"})
    end

    test "finds by instance", %{accounts: accounts} do
      assert {:ok, %{"username" => "bob", "instance" => "pixel.example"}} =
               Pixelfed.filter_by_key(accounts, %{"instance" => "pixel.example"})
    end

    test "returns error with Pixelfed label when not found" do
      assert {:error, "No Pixelfed account found for username charlie"} =
               Pixelfed.filter_by_key([], %{"username" => "charlie"})
    end
  end
end
