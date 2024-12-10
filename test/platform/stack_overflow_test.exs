defmodule TableauSocialExtension.Platform.StackOverflowTest do
  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform.StackOverflow

  describe "label/0" do
    test "returns Stack Overflow" do
      assert StackOverflow.label() == "Stack Overflow"
    end
  end

  describe "keys/0" do
    test "returns expected keys" do
      assert StackOverflow.keys() == ["id", "username"]
    end
  end

  describe "url_builder/1" do
    test "builds URL with id and username" do
      account = %{"id" => 12_345, "username" => "testuser"}
      assert {:ok, "https://stackoverflow.com/users/12345/testuser"} = StackOverflow.url_builder(account)
    end

    test "builds URL with id only" do
      account = %{"id" => 12_345}
      assert {:ok, "https://stackoverflow.com/users/12345"} = StackOverflow.url_builder(account)
    end

    test "returns error for invalid account" do
      assert {:error, "Invalid Stack Overflow account"} = StackOverflow.url_builder(%{"invalid" => "data"})
    end
  end

  describe "default_link_text/1" do
    test "returns username when available" do
      account = %{"id" => 12_345, "username" => "testuser"}
      assert {:ok, "testuser"} = StackOverflow.default_link_text(account)
    end

    test "returns id when username not available" do
      account = %{"id" => 12_345}
      assert {:ok, 12_345} = StackOverflow.default_link_text(account)
    end

    test "returns error for invalid account" do
      assert {:error, "Invalid Stack Overflow account"} = StackOverflow.default_link_text(%{"invalid" => "data"})
    end
  end

  describe "parse_account/1" do
    test "returns error for empty string" do
      assert {:error, error_msg} = StackOverflow.parse_account("")
      assert error_msg =~ "Stack Overflow account format must be 'id' or 'id/username'"
      assert error_msg =~ "got an empty string"
    end

    test "parses id only string" do
      assert {:ok, %{"id" => 12_345}} = StackOverflow.parse_account("12345")
    end

    test "parses id/username string" do
      assert {:ok, %{"id" => 12_345, "username" => "testuser"}} = StackOverflow.parse_account("12345/testuser")
    end

    test "parses id/username string with trailing slash" do
      assert {:ok, %{"id" => 12_345, "username" => "testuser"}} = StackOverflow.parse_account("12345/testuser/")
    end

    test "returns error for non-numeric id" do
      assert {:error, error_msg} = StackOverflow.parse_account("abc/testuser")
      assert error_msg =~ "Stack Overflow account format must be 'id' or 'id/username'"
    end

    test "returns error for zero id" do
      assert {:error, error_msg} = StackOverflow.parse_account("0/testuser")
      assert error_msg =~ "Invalid Stack Overflow 'id' (must be positive integer)"
    end

    test "handles negative numbers by extracting digits" do
      # The regex \d+ extracts just the digits from -123
      assert {:ok, %{"id" => 123, "username" => "testuser"}} = StackOverflow.parse_account("-123/testuser")
    end

    test "parses valid map with string keys and integer id" do
      account = %{"id" => 12_345, "username" => "testuser"}
      assert {:ok, ^account} = StackOverflow.parse_account(account)
    end

    test "parses valid map with string keys and string id" do
      account = %{"id" => "12345", "username" => "testuser"}
      expected = %{"id" => 12_345, "username" => "testuser"}
      assert {:ok, ^expected} = StackOverflow.parse_account(account)
    end

    test "parses map with id only" do
      account = %{"id" => 12_345}
      assert {:ok, ^account} = StackOverflow.parse_account(account)
    end

    test "parses valid map with atom keys" do
      account = %{id: 12_345, username: "testuser"}
      expected = %{"id" => 12_345, "username" => "testuser"}
      assert {:ok, ^expected} = StackOverflow.parse_account(account)
    end

    test "handles nil username in map" do
      account = %{"id" => 12_345, "username" => nil}
      expected = %{"id" => 12_345}
      assert {:ok, ^expected} = StackOverflow.parse_account(account)
    end

    test "handles empty username in map" do
      account = %{"id" => 12_345, "username" => ""}
      expected = %{"id" => 12_345}
      assert {:ok, ^expected} = StackOverflow.parse_account(account)
    end

    test "returns error for invalid map" do
      assert {:error, error_msg} = StackOverflow.parse_account(%{"invalid" => "data"})
      assert error_msg =~ "Stack Overflow accounts must have a 'id' positive integer value"
    end

    test "returns error for invalid id in map" do
      account = %{"id" => "invalid", "username" => "testuser"}
      assert {:error, "Invalid Stack Overflow 'id' (must be positive integer)"} = StackOverflow.parse_account(account)
    end

    test "returns error for zero id in map" do
      account = %{"id" => 0, "username" => "testuser"}
      assert {:error, "Invalid Stack Overflow 'id'"} = StackOverflow.parse_account(account)
    end
  end

  describe "filter_by_key/2" do
    setup do
      {:ok,
       accounts: [
         %{"id" => 12_345, "username" => "alice"},
         %{"id" => 67_890, "username" => "bob"},
         %{"id" => 11_111}
       ]}
    end

    test "finds exact match with slash format string", %{accounts: accounts} do
      assert {:ok, %{"id" => 12_345, "username" => "alice"}} =
               StackOverflow.filter_by_key(accounts, "12345/alice")
    end

    test "finds by id string", %{accounts: accounts} do
      assert {:ok, %{"id" => 67_890, "username" => "bob"}} =
               StackOverflow.filter_by_key(accounts, "67890")
    end

    test "finds by id map", %{accounts: accounts} do
      assert {:ok, %{"id" => 11_111}} =
               StackOverflow.filter_by_key(accounts, %{"id" => 11_111})
    end

    test "finds by username map", %{accounts: accounts} do
      assert {:ok, %{"id" => 12_345, "username" => "alice"}} =
               StackOverflow.filter_by_key(accounts, %{"username" => "alice"})
    end

    test "finds exact match with full map", %{accounts: accounts} do
      key = %{"id" => 12_345, "username" => "alice"}
      assert {:ok, ^key} = StackOverflow.filter_by_key(accounts, key)
    end

    test "returns error when no match found by id" do
      assert {:error, "No Stack Overflow account found for id 99999"} =
               StackOverflow.filter_by_key([], "99999")
    end

    test "returns error when no match found by username" do
      assert {:error, "No Stack Overflow account found for username nonexistent"} =
               StackOverflow.filter_by_key([], %{"username" => "nonexistent"})
    end

    test "returns error when multiple matches found by id", %{accounts: accounts} do
      accounts = accounts ++ [%{"id" => 12_345, "username" => "alice2"}]

      assert {:error, "Multiple Stack Overflow accounts found for id 12345"} =
               StackOverflow.filter_by_key(accounts, "12345")
    end

    test "returns error when multiple matches found by username", %{accounts: accounts} do
      accounts = accounts ++ [%{"id" => 99_999, "username" => "alice"}]

      assert {:error, "Multiple Stack Overflow accounts found for username alice"} =
               StackOverflow.filter_by_key(accounts, %{"username" => "alice"})
    end

    test "returns new account when exact match not found in accounts" do
      assert {:ok, %{"id" => 99_999, "username" => "newuser"}} =
               StackOverflow.filter_by_key([], "99999/newuser")
    end

    test "returns error for invalid id string" do
      assert {:error, error_msg} = StackOverflow.filter_by_key([], "invalid")
      assert error_msg =~ "Invalid Stack Overflow 'id' (must be positive integer)"
    end

    test "returns error for malformed slash format" do
      assert {:error, error_msg} = StackOverflow.filter_by_key([], "invalid/format")
      assert error_msg =~ "Stack Overflow account format must be 'id' or 'id/username'"
    end
  end
end
