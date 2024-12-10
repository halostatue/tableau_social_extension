defmodule TableauSocialExtension.ConfigTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TableauSocialExtension.Config

  describe "config/1" do
    test "accepts keyword list config" do
      assert {:ok, %{enabled: true}} = Config.config(enabled: true)
    end

    test "accepts map config" do
      assert {:ok, %{enabled: true}} = Config.config(%{enabled: true})
    end

    test "defaults enabled to false" do
      assert {:ok, %{enabled: false}} = Config.config(%{})
    end

    test "defaults css_prefix to social" do
      assert {:ok, %{css_prefix: "social"}} = Config.config(%{})
    end

    test "defaults accounts to empty map" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{})
      assert accounts == %{}
    end

    test "normalizes single account as string to list" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: "testuser"]})
      assert accounts == %{"github" => [%{"username" => "testuser"}]}
    end

    test "preserves multiple accounts as list" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: ["user1", "user2"]]})
      assert accounts == %{"github" => [%{"username" => "user1"}, %{"username" => "user2"}]}
    end

    test "excludes platforms with false value" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: "testuser", linkedin: false]})
      assert accounts == %{"github" => [%{"username" => "testuser"}]}
    end

    test "excludes platforms with nil value" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: "testuser", linkedin: nil]})
      assert accounts == %{"github" => [%{"username" => "testuser"}]}
    end

    test "handles custom css_prefix" do
      assert {:ok, %{css_prefix: "custom"}} = Config.config(%{css_prefix: "custom"})
    end

    test "handles nil css_prefix by using default" do
      assert {:ok, %{css_prefix: "social"}} = Config.config(%{css_prefix: nil})
    end

    test "returns error for invalid platform configuration" do
      assert {:error, error} = Config.config(%{platforms: %{"invalid" => 123}})
      assert error =~ "Platform invalid configuration invalid"
    end

    test "returns error for platform missing required label" do
      assert {:error, error} =
               Config.config(%{platforms: %{"test" => %{url_template: "https://example.com/{username}"}}})

      assert error =~ "Platform test missing required label"
    end

    test "returns error for platform missing URL builder" do
      assert {:error, error} = Config.config(%{platforms: %{"test" => %{label: "Test"}}})
      assert error =~ "Platform test missing required URL builder"
    end

    test "returns error for invalid handler module" do
      assert {:error, error} = Config.config(%{platforms: %{"test" => NonExistentModule}})
      assert error =~ "Platform test handler NonExistentModule cannot be loaded"
    end

    test "disables platforms with nil and false values in platforms config" do
      # Test that platforms can be disabled in the platforms config itself
      assert {:ok, %{platforms: platforms}} = Config.config(%{platforms: %{"github" => nil, "linkedin" => false}})
      refute Map.has_key?(platforms, "github")
      refute Map.has_key?(platforms, "linkedin")
    end
  end

  describe "platform handler validation" do
    test "validates handler function exports using invalid handler" do
      # Use a test module that doesn't have the required platform functions
      assert {:error, error} = Config.config(%{platforms: %{"test" => InvalidHandler}})
      assert error =~ "Platform test handler InvalidHandler does not export label/0"
    end
  end

  describe "error handling in account normalization" do
    test "logs warning and ignores invalid account format" do
      log =
        capture_log(fn ->
          assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [mastodon: "invalid-format"]})
          assert accounts == %{}
        end)

      assert log =~ "Platform mastodon failed to parse \"invalid-format\""
      assert log =~ "ignoring"
    end

    test "logs warning and ignores invalid account type" do
      log =
        capture_log(fn ->
          assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: 123]})
          assert accounts == %{}
        end)

      assert log =~ "Platform github invalid account: 123"
      assert log =~ "ignoring"
    end

    test "handles mixed valid and invalid accounts" do
      log =
        capture_log(fn ->
          assert {:ok, %{accounts: accounts}} =
                   Config.config(%{accounts: [github: ["valid-user", 123, "another-user"]]})

          assert accounts == %{"github" => [%{"username" => "valid-user"}, %{"username" => "another-user"}]}
        end)

      assert log =~ "Platform github invalid account: 123"
    end

    test "handles complex platform parsing errors" do
      log =
        capture_log(fn ->
          assert {:ok, %{accounts: accounts}} =
                   Config.config(%{accounts: ["stack-overflow": "invalid/format/too/many/parts"]})

          assert accounts == %{}
        end)

      assert log =~ "Platform stack-overflow failed to parse"
      assert log =~ "invalid/format/too/many/parts"
    end
  end

  describe "map-based account configuration" do
    test "handles string-keyed maps in account configuration" do
      assert {:ok,
              %{
                accounts: %{
                  "stack-overflow" => [%{"id" => 36_378, "username" => "austin-ziegler"}],
                  "mastodon" => [%{"username" => "user", "instance" => "mastodon.social"}]
                }
              }} =
               Config.config(
                 accounts: %{
                   "stack-overflow" => %{"id" => "36378", "username" => "austin-ziegler"},
                   mastodon: %{"username" => "user", "instance" => "mastodon.social"}
                 }
               )
    end

    test "converts snake_case platform keys to kebab-case" do
      assert {:ok,
              %{
                accounts: %{
                  "stack-overflow" => [%{"id" => 3733, "username" => "test-user"}],
                  "hacker-news" => [%{"username" => "another-user"}]
                }
              }} =
               Config.config(%{
                 accounts: %{
                   stack_overflow: "3733/test-user",
                   hacker_news: "another-user"
                 }
               })
    end
  end

  describe "deduplication" do
    test "deduplicates identical parsed accounts" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: ["user", "user", "other"]]})
      assert accounts == %{"github" => [%{"username" => "user"}, %{"username" => "other"}]}
    end

    test "deduplicates different representations of same account" do
      assert {:ok, %{accounts: accounts}} = Config.config(%{accounts: [github: ["user", %{"username" => "user"}]]})
      assert accounts == %{"github" => [%{"username" => "user"}]}
    end
  end
end
