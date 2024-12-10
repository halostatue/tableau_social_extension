defmodule TableauSocialExtension do
  @moduledoc """
  Tableau extension that replaces custom HTML tags with rendered social profile links.

  This extension processes `<dl social-block>` and `<a social-{platform}>` tags in
  rendered HTML and replaces them with properly formatted social media links based on
  platform account configuration.

  ## Quick Start

  Configure your social accounts:

  ```elixir
  config :tableau, TableauSocialExtension,
    enabled: true,
    accounts: [
      github: ["username", "orgname"],
      mastodon: "user@mastodon.social",
      linkedin: "username"
    ]
  ```

  Use in your content:

  ```html
  <!-- Social block with all accounts -->
  <dl social-block></dl>

  <!-- Individual social links -->
  <a social-github="username">GitHub Profile</a>
  <a social-mastodon="user@mastodon.social"></a>
  ```

  ## Configuration

  - `:enabled` (`t:boolean/0`): Extension is active or not.
  - `:css_prefix` (`t:String.t/0`): The CSS prefix to use. Defaults to `social`.
  - `:accounts` (`t:keyword/0` or `t:map/0`): Platform account definitions.
  - `:platforms` (`t:map/0`): Additional platform definitions.
  - `:show_errors` (`t:boolean/0`): Controls whether errors in processing are rendered as
    HTML.

  ### Platform Accounts

  Accounts may be configured in `config/config.exs` using either a keyword list or a map. The
  keys define the platform and the value may be a string or a list of strings. Platform
  keys will be normalized as kebab-style strings (`stack_overflow` will become
  `stack-overflow`).

  #### Frontmatter Account Configuration

  Accounts may also be configured in content frontmatter with the `social_accounts` map:

  - `{platform}`: Replaces the accounts configured for the `platform` with the account or
    accounts provided.

    This will make `elixir-lang` the only configured account for `github`:

    ```yaml
    social_accounts:
      github: elixir-lang
    ```

    If the value provided for the platform is `false` or `nil`, the platform will be
    disabled for the page. For platforms with usernames `false` or `nil`, provide these as
    strings or use a leading `@` before the username.

    ```yaml
    social_accounts:
      github: ['nil', '@false']
    ```

  - `{platform}[append]`: Appends the account or accounts provided to the list of accounts
    configured for the `platform`. If an account is _already present_ in the `platform`
    account list, it will be removed from the existing list and appended in the order
    provided.

    If `github` is already configured with `[elixir-tools, elixir-lang]`, then this will
    move `elixir-tools` to the end of the list:

    ```yaml
    social_accounts:
      github[append]: [elixir-ecto, elixir-tools]
    ```

    The result will be `[elixir-lang, elixir-ecto, elixir-tools]`.

  - `{platform}[prepend]`: Prepends the account or accounts provided to the list of
    accounts configured for the `platform`. If an account is _already present_ in the
    `platform` account list, it will be removed from the existing list and prepended in
    the order provided.

    If `github` is already configured with `[elixir-tools, elixir-lang]`, then this will
    move `elixir-lang` to the beginning of the list:

    ```yaml
    social_accounts:
      github[prepend]: [elixir-lang, elixir-ecto]
    ```

    The result will be `[elixir-lang, elixir-ecto, elixir-tools]`.

  Neither `{platform}[append]` nor `{platform}[prepend]` may be used with `{platform}`.
  If the same account is present in both `{platform}[append]` and `{platform}[prepend]`,
  the order is undefined.

  The `social_accounts` offers two non-platform directives, `[include]` and `[order]`.

  - `[include]`: Limits the platforms that will be included for use in the content. This
    is similar to specifying `{platform}: false`, but is more efficient.

    If accounts are configured for `github`, `mastodon`, `stack-overflow`, and `youtube`
    then the following will only include `github` and `mastodon` accounts:

    ```yaml
    social_accounts:
      [include]: [github, mastodon]
    ```

    The `[include]` directive affects both block and link tags.

  - `[order]`: Orders the platforms. By default, platforms are ordered alphabetically.
    The `[order]` directive specifies an explicit order; platforms not present present
    will be ordered alphabetically _after_ the named platforms.

    If accounts are configured for `github`, `mastodon`, `stack-overflow`, and `youtube`
    then the following will produce the order `mastodon`, `youtube`, `github`, and
    `stack-overflow`.

    ```yaml
    social_accounts:
      [order]: [mastodon, youtube]
    ```

  ### Platforms

  TableauSocialExtension ships with support for Bluesky, Facebook, GitHub, Hacker News,
  Instagram, Keybase, LinkedIn, Mastodon, Newsblur, PeerTube, Pinterest, Pixelfed, Reddit,
  Stack Overflow, Threads, TikTok, Tumblr, Twitter, and YouTube.

  Additional platforms may be added in configuration. See the [Platform
  Reference](guides/platform-reference.md) for details.

  ## Using TableauSocialExtension in Content

  TableauSocialExtension transforms social blocks (`<dl social-block></dl>`) and social
  links (`<a social-{platform}</a>`). It uses [Floki][floki] to parse and replace the HTML
  tags and works with any supported Floki parser.

  The CSS classes shown below assume the default prefix of `social`, but this can be
  changed with the `css_prefix` configuration.

  [floki]: https://hexdocs.pm/floki/

  ### Social Block (`<dl social-block></dl>`)

  The social block is a [description list][dl] with the attribute `social-block`. As an
  example, `<dl social-block></dl>` will generate the following HTML:

  ```html
  <dl class="social-block">
    <dt class="social-platform-label social-platform-github">GitHub</dt>
    <dd class="social-links social-platform-github">
      <a href="https://github.com/username" rel="noopener noreferrer nofollow"
         class="social-link social-link-github">@username</a>
    </dd>
  </dl>
  ```

  The entire social block is rendered as a `<dl>` tag, with the `social-block` CSS class
  added to any provided `class` names, so `<dl social-block class="links">` results in
  `<dl class="social-block links">`. If a `rel` attribute is present, it will be removed
  from the `<dl>` and applied to each of the account `<a>` links so that `<dl social-block
  rel="me">` becomes:

  ```html
  <dl class="social-block" rel="me">
    <dt class="social-platform-label social-platform-github">GitHub</dt>
    <dd class="social-links social-platform-github">
      <a href="https://github.com/username" rel="me noopener noreferrer nofollow"
         class="social-link social-link-github">@username</a>
    </dd>
  </dl>
  ```

  Any child elements or text nodes present in the social-block `<dl>` are ignored.

  Each platform is rendered as a `<dt>` (description term) tag with CSS classes
  `social-platform-label` and `social-platform-{platform}` and the platform label as the
  text node.

  All accounts for a platform are rendered in the `<dd>` (description details) tag with
  CSS classes `social-links` and `social-platform-{platform}`.

  Each account for a platform are rendered as `<a>` links with CSS classes `social-link`
  and `social-link-{platform}`. Any `rel` values from the original block will be added to
  the default `rel` values of `noopener`, `noreferrer`, and `nofollow`. The `href` and
  text node are rendered using platform configuration.

  [dl]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dl

  ### Social Link (`<a social-{platform}>`)

  The account link is an anchor element with the attribute `social-{platform}`, which can
  be provided with three distinct expressions:

  - `social-{platform}` or `social-{platform}=""` looks up the first account for
    `platform`. **Example**: `<a social-github></a>` uses the first GitHub account.

  - `social-{platform}="username"` looks up an account with `username`. For many social
    platforms, a properly formed username will render as a regular account. **Example**:
    `<a social-github="halostatue"></a>` will link to <https://github.com/halostatue>
    whether the account is configured or not.

  - `social-{platform}-{key}="value"` looks up an account whose `{key}` has the specified
    `value`. The keys permitted are determined by the platform; simple platforms only have
    the `username` key. More complex platforms may have additional keys. **Example**:
    `<a social-github-username="halostatue"></a>` does the same as a normal lookup.

  When the tag is replaced, existing HTML attributes will be preserved except for `rel`,
  `class`, and `href`. An `href` attribute will be ignored and replaced with the account's
  derived URL. `rel` values will be added to the default values of `noopener`,
  `noreferrer`, and `nofollow`. The `class` attribute will have `social-link` and
  `social-platform-{platform}` values added.

  Child elements present will be used as the body of the `<a>` link. If there are no
  children, then the default username format for the social platform will be used. As an
  example, these social links:

  ```html
  <a social-github class="github"><img src="/images/github.svg"></a>
  <a social-mastodon data-mastodon="true">Follow on Mastodon</a>
  <a social-youtube rel="me"></a>
  ```

  would become:

  ```html
  <a href="https://github.com/default" class="github social-link social-platform-github"
     rel="noopener noreferrer nofollow">
    <img src="/images/github.svg">
  </a>
  <a href="https://mastodon.example/@user" class="social-link social-platform-mastodon"
     rel="noopener noreferrer nofollow" data-mastodon="true">
    Follow on Mastodon
  </a>
  <a href="https://youtube.com/@default" class="social-link social-platform-youtube"
     rel="me noopener noreferrer nofollow">
    @default
  </a>
  ```

  ## Error Handling

  When `:show_errors` is enabled, configuration or usage errors are displayed visually in
  the browser. When disabled, errors are logged and invalid entries are silently skipped.

  ```elixir
  config :tableau, TableauSocialExtension,
    enabled: true,
    accounts: [
      github: ["username", "orgname"],
      mastodon: "user@mastodon.social",
      linkedin: "username"
    ],
    show_errors: config_env() != :prod
  ```
  """

  use Tableau.Extension, enabled: false, key: :social_accounts, priority: 900

  alias TableauSocialExtension.Config
  alias TableauSocialExtension.Platform
  alias TableauSocialExtension.SocialBlock
  alias TableauSocialExtension.SocialLink

  require Logger

  @impl Tableau.Extension
  defdelegate config(config), to: Config

  @impl Tableau.Extension
  def pre_write(token) do
    {:ok,
     put_in(
       token.site.pages,
       Enum.map(token.site.pages, &process_page(&1, token.extensions.social_accounts.config))
     )}
  end

  defp process_page(page, config) do
    case Floki.parse_document(page.body) do
      {:ok, html} ->
        put_in(page.body, replace_markers(html, page, config))

      {:error, reason} ->
        Logger.warning("Failed to parse HTML for page #{page.permalink}: #{inspect(reason)}")
        page
    end
  end

  defp replace_markers(html, page, config) do
    html
    |> Floki.traverse_and_update(&replace_marker(&1, page_config(page, config)))
    |> Floki.raw_html()
  end

  defp replace_marker({"dl", attrs, _children} = dl, config) do
    if social_block?(attrs) do
      SocialBlock.process(attrs, config)
    else
      dl
    end
  end

  defp replace_marker({"a", attrs, children} = a, config) do
    if social_link?(attrs) do
      SocialLink.process(attrs, children, config)
    else
      a
    end
  end

  defp replace_marker(other, _config), do: other

  defp social_block?(attrs), do: Enum.any?(attrs, &match?({"social-block", _}, &1))

  defp social_link?(attrs), do: Enum.any?(attrs, &match?({"social-" <> _, _}, &1))

  defp page_config(page, config) do
    config = Map.put(config, :permalink, page.permalink)

    case Map.fetch(page, :social_accounts) do
      {:ok, value} when value in [nil, false] ->
        config

      {:ok, value} when is_map(value) ->
        process_frontmatter_accounts(value, page, config)

      :error ->
        config

      _else ->
        Logger.warning("Invalid 'social_accounts' frontmatter for page #{page.permalink}")
        config
    end
  end

  defp process_frontmatter_accounts(frontmatter, page, config) do
    {include, frontmatter} = Map.pop(frontmatter, ["include"])
    {order, frontmatter} = Map.pop(frontmatter, ["order"])

    accounts =
      frontmatter
      |> handle_modifier_conflicts(page)
      |> resolve_frontmatter_accounts(config)
      |> Config.normalize_accounts(config)
      |> filter_included_accounts(include)

    Map.merge(config, %{accounts: accounts, order: order})
  end

  defp resolve_frontmatter_accounts(accounts, config) do
    Enum.reduce(accounts, config.accounts, &resolve_frontmatter_operation(&1, &2, config))
  end

  defp resolve_frontmatter_operation({key, platform_accounts}, accounts, config) do
    key = Config.normalize_platform_key(key)

    case Regex.named_captures(~r/^(?<type>[-\w]+)(?:\[(?<mod>append|prepend)\])?$/, key) do
      %{"type" => platform, "mod" => ""} ->
        Map.put(accounts, platform, platform_accounts)

      %{"type" => platform, "mod" => "append"} ->
        resolve_frontmatter_operation(:append, platform, platform_accounts, accounts, config)

      %{"type" => platform, "mod" => "prepend"} ->
        resolve_frontmatter_operation(:prepend, platform, platform_accounts, accounts, config)

      _ ->
        Logger.warning("Unknown platform or modifier #{key}: #{inspect(config)}")
        accounts
    end
  end

  defp resolve_frontmatter_operation(operation, platform, platform_accounts, accounts, config) do
    current =
      accounts
      |> Map.get(platform, [])
      |> List.wrap()

    handler = config.handlers[platform]

    new =
      platform_accounts
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.reduce([], fn account, platform_accounts ->
        case Platform.parse_account(platform, account, handler) do
          {:ok, account} ->
            [account | platform_accounts]

          {:error, reason} ->
            Logger.warning("Platform #{platform} failed to parse #{inspect(account)}: #{reason}; ignoring")
            platform_accounts
        end
      end)

    current = current -- new

    platform_accounts =
      case operation do
        :append -> current ++ new
        :prepend -> new ++ current
      end

    Map.put(accounts, platform, platform_accounts)
  end

  defp handle_modifier_conflicts(accounts, page) do
    accounts
    |> Map.keys()
    |> Enum.map(&Regex.named_captures(~r/(?<type>[-\w]+)(?:\[(?<mod>append|prepend)\])?/, to_string(&1)))
    |> Enum.group_by(& &1["type"], & &1["mod"])
    |> Enum.filter(fn {_k, v} -> Enum.any?(v, &(&1 == "")) && Enum.any?(v, &(&1 != "")) end)
    |> Enum.map(fn {k, v} -> {k, List.delete(v, "")} end)
    |> tap(fn conflicts ->
      if not Enum.empty?(conflicts) do
        Logger.warning("Page #{page.permalink} has issues in 'social_account' configuration")
      end
    end)
    |> Enum.reduce(accounts, fn {k, v}, accounts ->
      mods = Enum.map(v, &"#{k}[#{&1}]")

      Logger.warning(
        "Platform #{k} cannot use both base and modifier configs " <>
          "(#{Enum.join(mods, ", ")}); ignoring modifier configs"
      )

      Map.drop(accounts, mods)
    end)
  end

  defp filter_included_accounts(accounts, nil), do: accounts
  defp filter_included_accounts(accounts, []), do: accounts

  defp filter_included_accounts(accounts, include) do
    Map.take(accounts, Enum.map(include, &Config.normalize_platform_key/1))
  end
end
