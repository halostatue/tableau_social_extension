defmodule TableauSocialExtension.SocialBlockTest do
  @moduledoc false

  use TableauSocialExtension.PageCase, async: true

  import ExUnit.CaptureLog

  describe "social-block tag rendering" do
    test "does not affect non-social dl tags" do
      parsed =
        process_page(~s(<p>Test</p><dl><dt>Term</dt><dd>Definition</dd></dl>),
          accounts: %{github: ["testuser"], mastodon: ["user@example.com"]}
        )

      assert [] = Floki.find(parsed, "dl.social-block")
      assert [_] = Floki.find(parsed, "dl")
    end

    test "generates correct HTML structure" do
      parsed =
        process_page(~s(<p>Test</p><dl social-block rel="me"></dl>),
          accounts: %{github: ["testuser"], mastodon: ["user@example.com"]}
        )

      assert [_] = Floki.find(parsed, "dl.social-block")
      assert [_, _] = Floki.find(parsed, "dt")
      assert [_, _] = accounts = Floki.find(parsed, "dd")

      for account <- accounts do
        [classes] = Floki.attribute(account, "class")

        assert String.contains?(classes, "social-link")
        assert String.contains?(classes, "social-platform-")

        assert [link] = Floki.find(account, "a")

        rel =
          link
          |> Floki.attribute("rel")
          |> List.first()
          |> String.split()
          |> MapSet.new()

        assert rel == MapSet.new(~w[me noopener noreferrer nofollow])

        assert ["https://" <> _] = Floki.attribute(link, "href")
      end
    end

    test "verifies all platform URLs are correct" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{
            bluesky: ["test.example.com"],
            github: ["testuser"],
            linkedin: ["testprofile"],
            mastodon: ["@user@example.com"]
          }
        )

      assert [{"a", _, _}] = Floki.find(parsed, ~s(a[href="https://github.com/testuser"]))
      assert [{"a", _, _}] = Floki.find(parsed, ~s(a[href="https://example.com/@user"]))
      assert [{"a", _, _}] = Floki.find(parsed, ~s(a[href="https://linkedin.com/in/testprofile"]))
      assert [{"a", _, _}] = Floki.find(parsed, ~s(a[href="https://bsky.app/profile/test.example.com"]))
    end

    test "applies custom CSS prefix correctly" do
      parsed =
        process_page("<dl social-block></dl>",
          css_prefix: "custom-prefix",
          accounts: %{github: ["testuser"]}
        )

      assert [dl] = Floki.find(parsed, "dl")
      assert ["custom-prefix-block"] = Floki.attribute(dl, "class")
      assert [dd] = Floki.find(dl, "dd")

      [classes] = Floki.attribute(dd, "class")

      assert String.contains?(classes, "custom-prefix-link")
      assert String.contains?(classes, "custom-prefix-platform-github")
    end

    test "handles multiple social-block tags independently" do
      parsed =
        process_page(
          """
          <p>First marker:</p>
          <dl social-block></dl>
          <p>Second marker:</p>
          <dl social-block></dl>
          <p>Third marker:</p>
          <dl social-block></dl>
          """,
          accounts: %{github: ["testuser"], mastodon: ["user@example.com"], linkedin: ["profile"]}
        )

      assert [dl, dl, dl] = Floki.find(parsed, "dl.social-block")
    end
  end

  describe "social-block account deduplication" do
    test "deduplicates identical accounts in global config" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{github: ["user", "user", "different-user"]}
        )

      assert [_, _] = Floki.find(parsed, ~s(a[href^="https://github.com/"]))

      assert [_] = Floki.find(parsed, ~s(a[href^="https://github.com/user"]))
      assert [_] = Floki.find(parsed, ~s(a[href^="https://github.com/different-user"]))
    end

    test "deduplicates different string formats that parse to same account" do
      parsed = process_page("<dl social-block></dl>", accounts: %{github: ["user", "@user", %{"username" => "user"}]})

      assert [_] = Floki.find(parsed, ~s(a[href^="https://github.com/"]))
    end

    test "append modifier deduplicates parsed accounts" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"github[append]" => "@user"},
          accounts: %{github: [%{"username" => "user"}, "other-user"]}
        )

      assert result = Floki.find(parsed, ~s(a[href^="https://github.com/"]))
      assert [_, _] = result

      assert [["https://github.com/other-user"], ["https://github.com/user"]] =
               Enum.map(result, &Floki.attribute(&1, "href"))
    end

    test "prepend modifier deduplicates parsed accounts, not raw strings" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"github[prepend]" => "other-user"},
          accounts: %{github: ["@user", "other-user"]}
        )

      assert result = Floki.find(parsed, ~s(a[href^="https://github.com/"]))
      assert [_, _] = result

      assert [["https://github.com/other-user"], ["https://github.com/user"]] =
               Enum.map(result, &Floki.attribute(&1, "href"))
    end

    test "deduplication works with complex platforms" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{
            mastodon: ["user@mastodon.social", "@user@mastodon.social"],
            "stack-overflow": ["123/name", %{id: 123, username: "name"}]
          }
        )

      assert [_] = Floki.find(parsed, ~s(a[href^="https://mastodon.social/"]))
      assert [_] = Floki.find(parsed, ~s(a[href^="https://stackoverflow.com/"]))
    end
  end

  describe "social-block front matter configuration" do
    test "works correctly if omitted" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: :omit,
          accounts: %{
            github: ["testuser"],
            mastodon: ["user@example.com"],
            linkedin: ["profile"]
          }
        )

      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-github"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-mastodon"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-linkedin"]))
    end

    test "works correctly if false or nil" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: false,
          accounts: %{
            github: ["testuser"],
            mastodon: ["user@example.com"],
            linkedin: ["profile"]
          }
        )

      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-github"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-mastodon"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-linkedin"]))
    end

    test "errors usefully if social_accounts is not a map" do
      assert capture_log(fn ->
               process_page("<dl social-block></dl>",
                 frontmatter_accounts: 3,
                 accounts: %{
                   github: ["testuser"],
                   mastodon: ["user@example.com"],
                   linkedin: ["profile"]
                 }
               )
             end) =~ "Invalid 'social_accounts' frontmatter for page"
    end

    test "handles include filter from front matter" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"[include]" => ["github", "mastodon"]},
          accounts: %{
            github: ["testuser"],
            mastodon: ["user@example.com"],
            linkedin: ["profile"]
          }
        )

      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-github"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-mastodon"]))
      assert [] = Floki.find(parsed, ~s(dd[class~="social-platform-linkedin"]))
    end

    test "handles order configuration from front matter" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"[order]" => ["mastodon", "github"]},
          accounts: %{github: ["testuser"], mastodon: ["user@example.com"], linkedin: ["profile"]}
        )

      assert ["Mastodon", "GitHub", "LinkedIn"] ==
               parsed
               |> Floki.find("dt")
               |> Enum.map(&Floki.text/1)
    end

    test "handles URL replacement from front matter" do
      assert {:ok, %{site: %{pages: [%{body: body}]}}} =
               process_page("<dl social-block></dl>",
                 frontmatter_accounts: %{github: "different-user"},
                 accounts: %{github: ["original-user"], mastodon: ["user@example.com"]},
                 parse: false
               )

      assert String.contains?(body, "github.com/different-user")
      refute String.contains?(body, "github.com/original-user")
      assert String.contains?(body, "example.com/@user")
    end

    test "handles append modifier from front matter" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"github[append]" => "work-account"},
          accounts: %{github: ["personal-account"]}
        )

      assert [["https://github.com/personal-account"], ["https://github.com/work-account"]] ==
               parsed
               |> Floki.find(~s(a[href^="https://github.com/"]))
               |> Enum.map(&Floki.attribute(&1, "href"))
    end

    test "handles prepend modifier from front matter" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"github[prepend]" => "work-account"},
          accounts: %{github: ["personal-account"]}
        )

      assert [["https://github.com/work-account"], ["https://github.com/personal-account"]] ==
               parsed
               |> Floki.find(~s(a[href^="https://github.com/"]))
               |> Enum.map(&Floki.attribute(&1, "href"))
    end

    test "allows both append and prepend modifiers for same platform" do
      parsed =
        process_page("<dl social-block></dl>",
          frontmatter_accounts: %{"github[prepend]" => "first-account", "github[append]" => "last-account"},
          accounts: %{github: ["middle-account"]}
        )

      assert [
               ["https://github.com/first-account"],
               ["https://github.com/middle-account"],
               ["https://github.com/last-account"]
             ] ==
               parsed
               |> Floki.find(~s(a[href^="https://github.com/"]))
               |> Enum.map(&Floki.attribute(&1, "href"))
    end

    test "logs error for conflicting base and modifier forms" do
      log =
        capture_log(fn ->
          process_page("<dl social-block></dl>",
            frontmatter_accounts: %{"github" => "base-account", "github[append]" => "append-account"}
          )
        end)

      assert log =~ "Page /test has issues in 'social_account' configuration"
      assert log =~ "Platform github cannot use both base and modifier configs"
      assert log =~ "(github[append]); ignoring modifier configs"
    end

    test "omits platforms with empty account lists" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{github: ["testuser"], mastodon: [], linkedin: ["profile"]}
        )

      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-github"]))
      assert [] = Floki.find(parsed, ~s(dd[class~="social-platform-mastodon"]))
      assert [] = Floki.find(parsed, ~s(dt[class~="social-platform-mastodon"]))
      assert [_] = Floki.find(parsed, ~s(dd[class~="social-platform-linkedin"]))
    end
  end

  describe "social-block error handling" do
    test "shows error when no accounts are configured and show_errors: true" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{},
          show_errors: true
        )

      assert [{"div", _, _}] = Floki.find(parsed, "div.social-error")
      assert String.contains?(Floki.text(parsed), "Social Accounts Configuration Errors")
    end

    test "removes block when no accounts are configured and show_errors: false" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{},
          show_errors: false
        )

      assert [] = parsed
    end

    test "shows error for unknown platform and show_errors: true" do
      parsed = process_page("<dl social-block></dl>", accounts: %{unknown_platform: ["test"]})

      # NOTE: this should fail

      assert [{"li", _, [{"strong", _, ["unknown-platform:"]}, " Unknown platform in social block"]}] =
               Floki.find(parsed, "div.social-error li")
    end

    test "shows error for unknown platform in frontmatter and show_errors: true" do
      parsed = process_page("<dl social-block></dl>", frontmatter_accounts: %{unknown_platform: ["test"]})

      assert [{"li", _, [{"strong", _, ["unknown-platform:"]}, " Unknown platform in social block"]}] =
               Floki.find(parsed, "div.social-error li")
    end

    test "removes block for unknown platform and show_errors: false" do
      parsed = process_page("<dl social-block></dl>", accounts: %{unknown_platform: ["test"]}, show_errors: false)

      assert [] = parsed
    end

    test "shows error for invalid account format and show_errors: true" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{mastodon: ["invalid-format"]},
          show_errors: true
        )

      assert [{"div", _, _}] = Floki.find(parsed, "div.social-error")
    end

    test "removes block for invalid account format and show_errors: false" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{mastodon: ["invalid-format"]},
          show_errors: false
        )

      assert [] = parsed
    end

    test "shows multiple errors when multiple issues exist" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{unknown_platform: ["test"], mastodon: ["invalid"]},
          show_errors: true
        )

      assert [{"div", _, _}] = Floki.find(parsed, "div.social-error")
      error_text = Floki.text(parsed)
      assert String.contains?(error_text, "Unknown platform")
      assert String.contains?(error_text, "Social Accounts Configuration Errors")
    end

    test "error display includes debug information" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{unknown_platform: ["test"]},
          show_errors: true
        )

      assert [{"details", _, _}] = Floki.find(parsed, "details")
      assert [{"summary", _, _}] = Floki.find(parsed, "summary")
      assert String.contains?(Floki.text(parsed), "Debug Information")
    end

    test "with all account lists empty and show_errors: true" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{github: [], mastodon: [], linkedin: []},
          show_errors: true
        )

      assert [{"div", _, _}] = Floki.find(parsed, "div.social-error")
      assert String.contains?(Floki.text(parsed), "No social accounts configured")
    end

    test "with all account lists empty and show_errors: false" do
      parsed =
        process_page("<dl social-block></dl>",
          accounts: %{github: [], mastodon: [], linkedin: []},
          show_errors: false
        )

      assert [] = parsed
    end
  end
end
