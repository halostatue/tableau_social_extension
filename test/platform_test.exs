defmodule TableauSocialExtension.PlatformTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias TableauSocialExtension.Platform

  describe "parse_account/3 with nil handler" do
    test "strips @ prefix before parsing a string" do
      assert {:ok, %{"username" => "testuser"}} = Platform.parse_account(:test, "@testuser", nil)
    end

    test "returns parsed account when parsing a string" do
      assert {:ok, %{"username" => "testuser"}} = Platform.parse_account(:test, "testuser", nil)
    end

    test "returns parsed account when parsing a string-keyed map" do
      assert {:ok, %{"username" => "testuser"}} = Platform.parse_account(:test, %{"username" => "testuser"}, nil)
    end

    test "returns parsed account when parsing an atom-keyed map" do
      assert {:ok, %{"username" => "testuser"}} = Platform.parse_account(:test, %{username: "testuser"}, nil)
    end

    test "returns error when passed an empty string" do
      assert {:error, message} = Platform.parse_account(:failing, "", nil)
      assert message =~ ~s(failing accounts must not be empty strings)
    end

    test "returns error when passed an invalid map" do
      assert {:error, message} = Platform.parse_account(:failing, %{name: "testuser"}, nil)
      assert message =~ ~s(failing account maps must contain 'username' key)
    end
  end

  describe "parse_account/3 with a handler module" do
    test "returns parsed account on success" do
      assert {:ok, %{"name" => "testuser"}} = Platform.parse_account(:test, "testuser", WorkingHandler)
    end

    test "strips @ prefix before parsing" do
      assert {:ok, %{"name" => "testuser"}} = Platform.parse_account(:test, "@testuser", WorkingHandler)
    end

    test "returns error when handler fails (string)" do
      assert {:error, error_msg} = Platform.parse_account(:failing, "testuser", FailingHandler)

      assert error_msg =~ ~s(failing handler FailingHandler failed to parse account "testuser": Parse failed!)
    end

    test "returns error when handler fails (map)" do
      assert {:error, error_msg} = Platform.parse_account(:failing, %{}, FailingHandler)

      assert error_msg =~ ~s(failing handler FailingHandler failed to parse account %{})
    end
  end

  describe "substitute_template_fields/2" do
    test "substitutes single field" do
      assert {:ok, "https://example.com/testuser"} =
               Platform.substitute_template_fields("https://example.com/{username}", %{"username" => "testuser"})
    end

    test "substitutes multiple fields" do
      assert {:ok, "https://mastodon.social/testuser"} =
               Platform.substitute_template_fields("https://{instance}/{username}", %{
                 "username" => "testuser",
                 "instance" => "mastodon.social"
               })
    end

    test "leaves missing fields as placeholders" do
      assert {:ok, "https://example.com/testuser/{missing}"} =
               Platform.substitute_template_fields("https://example.com/{username}/{missing}", %{
                 "username" => "testuser"
               })
    end

    test "handles template with no placeholders" do
      template = "https://example.com/static"
      fields = %{"username" => "testuser"}
      assert {:ok, "https://example.com/static"} = Platform.substitute_template_fields(template, fields)
    end
  end

  describe "build_url/3" do
    test "builds URL using url_template" do
      assert {:ok, "https://test.com/testuser"} =
               Platform.build_url(:test, %{"username" => "testuser"}, %{
                 test: %{
                   label: "Test",
                   url_template: "https://test.com/{username}",
                   handler: WorkingHandler
                 }
               })
    end

    test "builds URL using url_builder with {:ok, url} return" do
      assert {:ok, "https://success.com/testuser"} =
               Platform.build_url(:test, %{"username" => "testuser"}, %{
                 test: %{
                   label: "Test",
                   url_builder: {SuccessUrlBuilder, :build, []},
                   handler: WorkingHandler
                 }
               })
    end

    test "returns error when url_builder returns error" do
      platforms = %{test: %{label: "Test", url_builder: {FailingUrlBuilder, :build, []}, handler: FailingHand}}

      assert {:error, error_msg} = Platform.build_url(:test, %{"username" => "testuser"}, platforms)
      assert error_msg =~ "URL builder"
      assert error_msg =~ "failed"
    end

    test "returns error for unknown platform" do
      assert {:error, error_msg} = Platform.build_url(:unknown, "testuser", %{})
      assert error_msg =~ "Unknown platform"
    end
  end
end
