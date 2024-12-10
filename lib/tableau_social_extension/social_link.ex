defmodule TableauSocialExtension.SocialLink do
  @moduledoc false

  alias TableauSocialExtension.Platform
  alias TableauSocialExtension.Render

  require Logger

  def process(attrs, children, config) do
    case resolve_social_platform(attrs, config) do
      {:ok, platform, value} ->
        process_platform(platform, value, attrs, children, config)

      {:error, reason} ->
        Render.render_errors(reason, config, :link)
    end
  end

  defp resolve_social_platform(attrs, config) do
    case Enum.reduce(attrs, %{errors: [], platforms: %{}}, &resolve_social_platform_attr(&1, &2, config)) do
      %{errors: [], platforms: platforms} ->
        resolve_platform_lookup(platforms, map_size(platforms))

      %{errors: errors} ->
        {:error, Enum.join(errors, "\n")}
    end
  end

  defp resolve_platform_lookup(_platforms, 0) do
    {:error, "No social platform attributes found"}
  end

  defp resolve_platform_lookup(platforms, 1) do
    platforms
    |> Map.to_list()
    |> resolve_platform_lookup()
  end

  defp resolve_platform_lookup(platforms, count) do
    {:error, "#{count} social platform attributes found: #{Enum.join(Map.keys(platforms), ", ")}"}
  end

  defp resolve_platform_lookup([{platform, [{_, _}] = value}]) do
    {:ok, platform, Map.new(value)}
  end

  defp resolve_platform_lookup([{platform, [value]}]) do
    {:ok, platform, value}
  end

  defp resolve_platform_lookup([{platform, values}]) do
    cond do
      Enum.all?(values, &(is_tuple(&1) and tuple_size(&1) == 2)) ->
        dups =
          values
          |> Enum.frequencies_by(&elem(&1, 0))
          |> Enum.filter(&(elem(&1, 1) > 1))
          |> Enum.map(&elem(&1, 0))

        case dups do
          [] -> {:ok, platform, Map.new(values)}
          _ -> {:error, "#{platform} has multiple values for lookup keys: #{Enum.join(dups, ", ")}"}
        end

      Enum.all?(values, &is_binary/1) ->
        {:error, "#{platform} has multiple values for account lookup"}

      Enum.all?(values, &is_atom/1) ->
        {:error, "#{platform} has multiple default account entries"}

      true ->
        {:error, "#{platform} has a mix of account lookup, default account, and/or lookup keys"}
    end
  end

  defp resolve_social_platform_attr({"social-" <> candidate = attr, value}, result, config)
       when value == "" or value == attr do
    config.social_link_match
    |> Regex.named_captures(attr)
    |> resolve_attr(result, config, :default, candidate, attr)
  end

  defp resolve_social_platform_attr({"social-" <> candidate = attr, value}, result, config) do
    config.social_link_match
    |> Regex.named_captures(attr)
    |> resolve_attr(result, config, value, candidate, attr)
  end

  defp resolve_social_platform_attr({_, _}, result, _config), do: result

  defp resolve_attr(%{"platform" => platform, "key" => ""}, result, config, value, _candidate, _attr) do
    if config.platforms[platform] do
      update_in(result, [:platforms, platform], &[value | &1 || []])
    else
      update_in(result.errors, &["#{platform} has been disabled" | &1])
    end
  end

  defp resolve_attr(%{"platform" => platform, "key" => key}, result, config, value, _candidate, attr) do
    cond do
      is_nil(config.platforms[platform]) ->
        update_in(result.errors, &["#{platform} has been disabled" | &1])

      value == :default and key in config.platforms[platform].keys ->
        update_in(result.errors, &["#{platform} lookup key #{key} may not be empty or boolean" | &1])

      key in config.platforms[platform].keys ->
        update_in(result, [:platforms, platform], &[{key, value} | &1 || []])

      true ->
        update_in(result.errors, &["#{platform} unknown lookup key: #{attr}" | &1])
    end
  end

  defp resolve_attr(nil, result, _config, _value, candidate, _attr) do
    update_in(result.errors, &["Unknown platform #{candidate}" | &1])
  end

  defp process_platform(platform, value, attrs, children, config) do
    with {:ok, account} <- resolve_account(platform, value, config),
         {:ok, html} <- render_social_link(platform, account, attrs, children, config) do
      html
    else
      {:error, reason} ->
        Render.render_errors({platform, reason}, config, :link)
    end
  end

  defp resolve_account(platform, value, config) do
    case Map.fetch(config.platforms, platform) do
      {:ok, platform_config} ->
        resolve_platform_account(platform, value, platform_config, Map.get(config.accounts, platform, []))

      :error ->
        {:error, "Unknown platform #{platform}"}
    end
  end

  defp resolve_platform_account(platform, :default, _platform_config, []) do
    {:error, "No account configured for platform '#{platform}'"}
  end

  defp resolve_platform_account(_platform, :default, _platform_config, [first | _]) do
    {:ok, first}
  end

  defp resolve_platform_account(platform, value, platform_config, accounts) do
    value = if is_binary(value), do: String.trim_leading(value, "@"), else: value
    handler = Map.get(platform_config, :handler)

    result =
      if handler do
        handler.filter_by_key(accounts, value)
      else
        case Enum.filter(accounts, &(&1["username"] == value)) do
          [account] -> {:ok, account}
          [] -> :error
          [_ | _] -> {:error, "#{platform} has multiple configurations for username #{value}"}
        end
      end

    case result do
      {:ok, account} -> {:ok, account}
      :error -> Platform.parse_account(platform, value, handler)
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_social_link(platform, account, attrs, children, config) do
    with {:ok, link} <- Platform.link_content(children, platform, account, config.platforms),
         {:ok, url} <- Platform.build_url(platform, account, config.platforms) do
      {:ok,
       {
         "a",
         process_attributes(attrs, platform, config.css_prefix, url),
         List.wrap(link)
       }}
    else
      {:error, reason} ->
        {:error, "Failed to render link: #{reason}"}
    end
  end

  defp process_attributes(attrs, platform, css_prefix, url) do
    attrs
    |> List.keydelete("social-#{platform}", 0)
    |> Render.ensure_attribute_value_list("href", [url])
    |> Render.ensure_attribute_value_list("class", ["#{css_prefix}-link", "#{css_prefix}-platform-#{platform}"])
    |> Render.ensure_attribute_value_list("rel", ["nofollow", "noopener", "noreferrer"])
  end
end
