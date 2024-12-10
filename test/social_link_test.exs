defmodule TableauSocialExtension.SocialLinkTest do
  use TableauSocialExtension.PageCase, async: true

  alias TableauSocialExtension.Platform.StackOverflow

  describe "social-{platform} tag rendering" do
    test "does not modify non-social-{platform} tags" do
      parsed =
        process_page(~s(<p>Follow me on <a href="user1" rel="me">GitHub</a>.</p>),
          accounts: %{github: ["user1"]}
        )

      assert [] = Floki.find(parsed, "a.social-link")
      assert [_] = Floki.find(parsed, "a")
    end

    test "generates correct HTML structure for individual links" do
      parsed =
        process_page(~s(<p>Follow me on <a social-github="user1" rel="me">GitHub</a>.</p>),
          accounts: %{github: ["user1"]}
        )

      assert [link] = Floki.find(parsed, "a.social-link")

      [classes] = Floki.attribute(link, "class")

      assert String.contains?(classes, "social-link")
      assert String.contains?(classes, "social-platform-github")

      rel =
        link
        |> Floki.attribute("rel")
        |> List.first()
        |> String.split()
        |> MapSet.new()

      assert rel == MapSet.new(~w[me noopener noreferrer nofollow])

      assert ["https://github.com/user1"] = Floki.attribute(link, "href")

      assert "GitHub" = Floki.text(link)
    end

    test "uses first configured account for boolean attribute" do
      parsed = process_page(~s(<a social-github></a>), accounts: %{github: ["user2", "user1"]})

      assert [{"a", _, _}] = Floki.find(parsed, ~s(a[href="https://github.com/user2"]))
      assert [] = Floki.find(parsed, ~s(a[href="https://github.com/user1"]))
    end

    test "supports keyed attributes for simple platforms" do
      parsed = process_page(~s(<a social-github="user2">GitHub</a>), accounts: %{github: ["user1"]})

      assert [{"a", _, children}] = Floki.find(parsed, ~s(a[href="https://github.com/user2"]))
      assert "GitHub" == Floki.text(children)
    end

    test "supports kebab-case platform names" do
      parsed =
        process_page(~s(<a social-stack-overflow="12345">Stack Overflow</a>),
          accounts: [stack_overflow: ["12345/abcdef"]]
        )

      assert [{"a", _, children}] = Floki.find(parsed, ~s(a[href="https://stackoverflow.com/users/12345/abcdef"]))
      assert "Stack Overflow" == Floki.text(children)
    end

    test "supports complex lookups if the platform does" do
      parsed =
        process_page(~s(<a social-stack-overflow="12345/austin-ziegler">Profile</a>),
          platforms: %{stack_overflow: StackOverflow}
        )

      assert [{"a", _, children}] =
               Floki.find(parsed, ~s(a[href="https://stackoverflow.com/users/12345/austin-ziegler"]))

      assert "Profile" == Floki.text(children)
    end

    test "errors on mixed platform attributes" do
      parsed =
        process_page(~s(<a social-github="user1" social-mastodon="user@example.com">Mixed</a>),
          show_errors: true,
          accounts: %{github: ["testuser"], mastodon: ["user@mastodon.social"]}
        )

      assert [{"details", _, children}] = Floki.find(parsed, "details.social-error-link")

      assert "2 social platform attributes found: github, mastodon" ==
               children
               |> Floki.find("li")
               |> Floki.text()
    end

    test "handles @ prefix stripping" do
      parsed =
        process_page(~s(<a social-github="@testuser">GitHub</a>),
          accounts: %{github: ["configured-user"]}
        )

      assert [_] = Floki.find(parsed, ~s(a[href="https://github.com/testuser"]))
      assert [] = Floki.find(parsed, ~s(a[href="https://github.com/@testuser"]))
    end

    test "uses resolved frontmatter values for partial lookups" do
      parsed =
        process_page(~s(<a social-github>GitHub</a>),
          frontmatter_accounts: %{github: "frontmatter-user"},
          accounts: %{github: ["global-user"]}
        )

      assert [_] = Floki.find(parsed, ~s(a[href="https://github.com/frontmatter-user"]))
      assert [] = Floki.find(parsed, ~s(a[href="https://github.com/global-user"]))
    end

    test "returns an error if there is a link for a disabled platform" do
      assert ~s(<a social-github>GitHub</a>)
             |> process_page(
               frontmatter_accounts: %{github: nil},
               accounts: %{github: ["global-user"]}
             )
             |> Floki.text() =~ " No account configured for platform 'github'"
    end

    test "allows complete specification without configuration" do
      parsed =
        process_page(~s(<a social-github="zenspider">Ryan Davis</a> <a social-github="@github">GitHub</a>),
          accounts: %{}
        )

      assert [a] = Floki.find(parsed, ~s(a[href="https://github.com/zenspider"]))
      assert "Ryan Davis" == Floki.text(a)

      assert [a] = Floki.find(parsed, ~s(a[href="https://github.com/github"]))
      assert "GitHub" == Floki.text(a)
    end

    test "preserves child elements like images" do
      parsed =
        process_page(~s(<a social-github="testuser"><img src="/images/github.svg"></a>),
          accounts: %{github: ["otheruser"]}
        )

      assert [{"a", _attrs, children}] = Floki.find(parsed, ~s(a[href="https://github.com/testuser"]))
      assert [{"img", [{"src", "/images/github.svg"}], []}] = children
    end
  end

  describe "social platform parsing validation" do
    valid = [
      # Valid exact matches
      {
        "exact match empty",
        [{"social-github", ""}],
        "https://github.com/username"
      },
      {
        "exact match self-reference",
        [{"social-github", "social-github"}],
        "https://github.com/username"
      },
      {
        "mastodon exact match empty",
        [{"social-mastodon", ""}],
        "https://example.com/@username"
      },

      # Valid key matches
      {
        "github with username",
        [{"social-github-username", "testuser"}],
        "https://github.com/testuser"
      },
      {
        "mastodon with username",
        [{"social-mastodon-username", "username"}],
        "https://example.com/@username"
      },
      {
        "mastodon with instance",
        [{"social-mastodon-instance", "example.com"}],
        "https://example.com/@username"
      },
      {
        "stack overflow with id",
        [{"social-stack-overflow-id", "12345"}],
        "https://stackoverflow.com/users/12345/test-user"
      },
      {
        "stack overflow with username",
        [{"social-stack-overflow-username", "test-user"}],
        "https://stackoverflow.com/users/12345/test-user"
      },

      # Multiple keys for same platform
      {
        "mastodon multiple keys",
        [{"social-mastodon-username", "user"}, {"social-mastodon-instance", "example.com"}],
        "https://example.com/@user"
      },
      {
        "stack overflow multiple keys",
        [
          {
            "social-stack-overflow-id",
            "54321"
          },
          {"social-stack-overflow-username", "other-user"}
        ],
        "https://stackoverflow.com/users/54321/other-user"
      },
      {
        "non-social attrs mixed in",
        [{"class", "test"}, {"social-github-username", "user"}],
        "https://github.com/user"
      }
    ]

    invalid = [
      # # Invalid cases
      {
        "empty key value",
        [{"social-github-username", ""}],
        "github lookup key username may not be empty or boolean"
      },
      {
        "self-reference key",
        [{"social-github-username", "social-github-username"}],
        "github lookup key username may not be empty or boolean"
      },
      {
        "multiple self-reference",
        [{"social-github", ""}, {"social-github", ""}],
        "github has multiple default account entries"
      },
      {
        "base and key",
        [{"social-github", "username"}, {"social-github-username", "username"}],
        "github has a mix of account lookup, default account, and/or lookup keys"
      },
      {
        "base and base",
        [{"social-github", "name1"}, {"social-github", "name2"}],
        "github has multiple values for account lookup"
      },
      {
        "boolean and base",
        [{"social-github", "social-github"}, {"social-github", "github"}],
        "github has a mix of account lookup, default account, and/or lookup keys"
      },
      {
        "invalid key",
        [{"social-github-invalid", "test"}],
        "github unknown lookup key: social-github-invalid"
      },
      {
        "duplicate keys",
        [
          {
            "social-mastodon-instance",
            "instance1.example.com"
          },
          {"social-mastodon-instance", "instance2.example.com"}
        ],
        "mastodon has multiple values for lookup keys: instance"
      },
      {
        "unknown platform",
        [{"social-unknown", "test"}],
        "Unknown platform unknown"
      },
      {
        "unknown platform with key",
        [{"social-unknown-key", "test"}],
        "Unknown platform unknown-key"
      },

      # Multiple platforms (should error)
      {
        "multiple platforms",
        [{"social-github-username", "user1"}, {"social-twitter-username", "user2"}],
        "2 social platform attributes found: github, twitter"
      },

      # Mixed valid/invalid
      {
        "mixed valid/invalid keys",
        [{"social-github-username", "valid"}, {"social-github-invalid", "invalid"}],
        "github unknown lookup key: social-github-invalid"
      }
    ]

    config =
      build_config(
        accounts: %{
          "github" => "@username",
          "linkedin" => "@linkedin",
          "mastodon" => "@username@example.com",
          "stack-overflow" => "12345/test-user",
          "twitter" => "@username"
        }
      )

    config = Macro.escape(config)

    for {title, attrs, url} <- valid do
      test "Valid: #{title}" do
        parsed = TableauSocialExtension.SocialLink.process(unquote(attrs), [], unquote(config))

        assert [_] = Floki.find(parsed, ~s(a[href="#{unquote(url)}"]))
      end
    end

    for {title, attrs, error} <- invalid do
      test "Invalid: #{title}" do
        parsed = TableauSocialExtension.SocialLink.process(unquote(attrs), [], unquote(config))

        assert [li] = Floki.find(parsed, ~s(details.social-error-link ul li))

        assert unquote(error) == Floki.text(li)
      end
    end
  end
end
