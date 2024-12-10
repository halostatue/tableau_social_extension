defmodule TableauSocialExtension.Config do
  @moduledoc false

  alias TableauSocialExtension.Platform
  alias TableauSocialExtension.Platform.Mastodon
  alias TableauSocialExtension.Platform.PeerTube
  alias TableauSocialExtension.Platform.Pixelfed
  alias TableauSocialExtension.Platform.Reddit
  alias TableauSocialExtension.Platform.StackOverflow

  require Logger

  @default_css_prefix "social"
  @defaults %{
    enabled: false,
    css_prefix: @default_css_prefix,
    accounts: [],
    platforms: %{},
    social_link_match: nil,
    handlers: %{}
  }

  @default_platforms %{
    "bluesky" => %{label: "Bluesky", url_template: "https://bsky.app/profile/{username}"},
    "facebook" => %{label: "Facebook", url_template: "https://facebook.com/{username}"},
    "github" => %{label: "GitHub", default_link_text: "@{username}", url_template: "https://github.com/{username}"},
    "hacker-news" => %{label: "Hacker News", url_template: "https://news.ycombinator.com/user?id={username}"},
    "instagram" => %{label: "Instagram", url_template: "https://instagram.com/{username}"},
    "keybase" => %{label: "Keybase", url_template: "https://keybase.io/{username}"},
    "linkedin" => %{label: "LinkedIn", url_template: "https://linkedin.com/in/{username}"},
    "mastodon" => Mastodon,
    "newsblur" => %{label: "Newsblur", url_template: "https://{username}.newsblur.com"},
    "peertube" => PeerTube,
    "pinterest" => %{label: "Pinterest", url_template: "https://pinterest.com/{username}"},
    "pixelfed" => Pixelfed,
    "reddit" => Reddit,
    "stack-overflow" => StackOverflow,
    "threads" => %{label: "Threads", url_template: "https://threads.net/@{username}"},
    "tiktok" => %{label: "TikTok", url_template: "https://tiktok.com/@{username}"},
    "tumblr" => %{label: "Tumblr", url_template: "https://{username}.tumblr.com/"},
    "twitter" => %{label: "Twitter", url_template: "https://twitter.com/{username}"},
    "youtube" => %{label: "YouTube", url_template: "https://youtube.com/@{username}"}
  }

  def defaults, do: @defaults
  def default_platforms, do: @default_platforms

  def config(config) when is_list(config), do: config(Map.new(config))

  def config(config) do
    config = Map.merge(defaults(), config)

    case process_platforms(config) do
      {:ok, config} ->
        accounts = normalize_accounts(config.accounts, config)

        result =
          config
          |> Map.take([:enabled, :handlers, :platforms, :social_link_match])
          |> Map.merge(%{
            css_prefix: config.css_prefix || @default_css_prefix,
            show_errors: Map.get(config, :show_errors, false),
            accounts: accounts
          })

        {:ok, result}

      {:error, reason} ->
        {:error, Enum.join(List.wrap(reason), "\n")}
    end
  end

  def normalize_accounts(accounts, config) when is_map(accounts) or is_list(accounts) do
    accounts
    |> Enum.reduce(%{}, &normalize_account(&1, &2, config))
    |> deduplicate_accounts()
  end

  # Deduplicate parsed account maps for each platform
  defp deduplicate_accounts(accounts) do
    Map.new(accounts, fn {platform, accounts} ->
      {platform, Enum.uniq(accounts)}
    end)
  end

  def normalize_platform_key(key), do: String.replace(to_string(key), "_", "-")

  defguard is_config_string(value) when is_binary(value) and value != ""

  defguard is_url_builder(value) when is_tuple(value) and tuple_size(value) == 3

  defp process_platforms(config) do
    platforms = Enum.concat(default_platforms(), config.platforms)

    pattern =
      platforms
      |> Enum.map(&normalize_platform_key(elem(&1, 0)))
      |> Enum.uniq()
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.join("|")

    case Enum.reduce(platforms, %{platforms: %{}, errors: []}, &process_platform/2) do
      %{errors: [], platforms: platforms} ->
        {:ok,
         %{
           config
           | handlers: Map.new(platforms, fn {k, v} -> {k, Map.get(v, :handler)} end),
             platforms: platforms,
             social_link_match: ~r/^social-(?<platform>#{pattern})(?:-(?<key>[-\w]+))?$/
         }}

      %{errors: errors} ->
        {:error, errors}
    end
  end

  defp process_platform({platform, value}, token) do
    case process_platform(platform, value, token) do
      {:ok, platforms} -> %{token | platforms: platforms}
      {:error, reason} -> %{token | errors: token.errors ++ List.wrap(reason)}
    end
  end

  defp process_platform(platform, value, token) when value in [nil, false] do
    {:ok, Map.delete(token.platforms, platform)}
  end

  defp process_platform(platform, handler, token) when is_atom(handler) do
    case process_platform_handler(platform, handler) do
      {:ok, metadata} -> {:ok, Map.put(token.platforms, platform, metadata)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_platform(platform, config, token) when is_map(config) do
    case platform_metadata(platform, Map.get(config, :handler)) do
      {:ok, metadata} ->
        config = Map.merge(metadata, config)

        errors =
          Enum.filter(
            [
              is_config_string(config[:label]) || "Platform #{platform} missing required label",
              is_config_string(config[:url_template]) || is_url_builder(config[:url_builder]) ||
                "Platform #{platform} missing required URL builder (url_template or url_builder)"
            ],
            &is_binary/1
          )

        if errors == [] do
          {:ok, Map.put(token.platforms, platform, config)}
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_platform(platform, _value, _token) do
    {:error, "Platform #{platform} configuration invalid (must be handler module or map)"}
  end

  defp platform_metadata(_platform, nil), do: {:ok, Platform.__metadata__(nil)}

  defp platform_metadata(platform, handler) do
    case Code.ensure_loaded(handler) do
      {:module, ^handler} ->
        {:ok, Platform.__metadata__(handler)}

      {:error, reason} ->
        {:error, "Platform #{platform} handler #{Macro.to_string(handler)} cannot be loaded: #{inspect(reason)}"}
    end
  end

  defp process_platform_handler(platform, handler) do
    name = Macro.to_string(handler)

    case platform_metadata(platform, handler) do
      {:ok, metadata} ->
        errors =
          Enum.filter(
            [
              function_exported?(handler, :label, 0) ||
                "Platform #{platform} handler #{name} does not export label/0",
              function_exported?(handler, :url_template, 0) ||
                function_exported?(handler, :url_builder, 1) ||
                "Platform #{platform} handler #{name} does not export url_template/0 or url_builder/1"
            ],
            &is_binary/1
          )

        if errors == [] do
          {:ok, metadata}
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_account({platform, value}, accounts, config) do
    normalize_account(normalize_platform_key(platform), value, accounts, config)
  end

  defp normalize_account(platform, value, accounts, _config) when value in [false, nil] do
    Map.delete(accounts, platform)
  end

  defp normalize_account(platform, account, accounts, config) when is_binary(account) or is_map(account) do
    case Platform.parse_account(platform, account, config.handlers[platform]) do
      {:ok, parsed_account} ->
        Map.put(accounts, platform, Map.get(accounts, platform, []) ++ [parsed_account])

      {:error, reason} ->
        Logger.warning("Platform #{platform} failed to parse #{inspect(account)}: #{reason}; ignoring")
        accounts
    end
  end

  defp normalize_account(platform, platform_accounts, accounts, config) when is_list(platform_accounts) do
    Enum.reduce(platform_accounts, accounts, &normalize_account(platform, &1, &2, config))
  end

  defp normalize_account(platform, value, accounts, _config) do
    Logger.warning("Platform #{platform} invalid account: #{inspect(value)}; ignoring")
    accounts
  end
end
