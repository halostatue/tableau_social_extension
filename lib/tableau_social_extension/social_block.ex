defmodule TableauSocialExtension.SocialBlock do
  @moduledoc false

  alias TableauSocialExtension.Platform
  alias TableauSocialExtension.Render

  @spec process(list(tuple()), map()) :: tuple() | String.t()
  def process(attrs, config) do
    config = Map.put(config, :rel, get_attribute_value(attrs, "rel"))

    attrs = process_dl_attributes(attrs, config)
    accounts = platform_accounts(config.accounts)

    case render_links(accounts, config, attrs) do
      {:ok, html} -> html
      {:error, :no_accounts} -> Render.render_no_accounts_error(config)
      {:error, errors} -> Render.render_errors(errors, config, :block)
    end
  end

  defp process_dl_attributes(attrs, config) do
    attrs
    |> List.keydelete("social-block", 0)
    |> List.keydelete("rel", 0)
    |> Render.ensure_attribute_value_list("class", ["#{config[:css_prefix]}-block"])
  end

  defp render_links(accounts, config, attrs) do
    if Enum.empty?(accounts) do
      {:error, :no_accounts}
    else
      case group_and_render_accounts(accounts, config) do
        {:ok, items} -> {:ok, {"dl", attrs, items}}
        {:error, errors} -> {:error, errors}
      end
    end
  end

  defp group_and_render_accounts(accounts, config) do
    {errors, accounts} =
      Enum.split_with(accounts, fn
        {_platform, {_error_platform, _error_message}} -> true
        {_platform, _account} -> false
      end)

    errors = Enum.map(errors, &elem(&1, 1))

    if Enum.empty?(errors) do
      result =
        accounts
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> sort_platforms_by_order(Map.get(config, :order))
        |> Enum.reduce({[], []}, &render_platform_group(&1, &2, config))

      case result do
        {items, []} -> {:ok, items}
        {_, errors} -> {:error, errors}
      end
    else
      {:error, errors}
    end
  end

  defp render_platform_group({k, v}, {items, errors}, config) do
    case render_platform_group(k, v, config) do
      {:ok, platform_items} -> {items ++ platform_items, errors}
      {:error, platform_errors} -> {items, errors ++ platform_errors}
    end
  end

  defp render_platform_group(platform, accounts, config) do
    case Map.fetch(config.platforms, platform) do
      {:ok, platform_config} -> render_platform_with_config(platform, accounts, platform_config, config)
      :error -> {:error, [{platform, "Unknown platform in social block"}]}
    end
  end

  defp render_platform_with_config(platform, accounts, platform_config, config) do
    label = platform_config.label
    dt = {"dt", [{"class", "#{config.css_prefix}-platform-label #{config.css_prefix}-platform-#{platform}"}], [label]}

    {links, errors} = collect_account_links(accounts, platform, config)

    if Enum.empty?(errors) do
      dd =
        {"dd", [{"class", "#{config.css_prefix}-links #{config.css_prefix}-platform-#{platform}"}], Enum.reverse(links)}

      {:ok, [dt, dd]}
    else
      {:error, errors}
    end
  end

  defp collect_account_links(accounts, platform, config) do
    Enum.reduce(accounts, {[], []}, fn account, {acc_links, acc_errors} ->
      case render_account_link(platform, account, config) do
        {:ok, link} -> {[link | acc_links], acc_errors}
        {:error, error} -> {acc_links, [error | acc_errors]}
      end
    end)
  end

  defp render_account_link(platform, account, config) do
    with {:ok, link} <- Platform.link_content(platform, account, config.platforms),
         {:ok, url} <- Platform.build_url(platform, account, config.platforms) do
      {:ok,
       {
         "a",
         [
           {"href", url},
           {"rel", Render.merge_value_list(config.rel, ["nofollow", "noopener", "noreferrer"])},
           {"class", "#{config.css_prefix}-link #{config.css_prefix}-#{platform}"}
         ],
         [link]
       }}
    else
      {:error, reason} ->
        {:error, "Failed to render link: #{reason}"}
    end
  end

  defp platform_accounts(accounts) do
    Enum.flat_map(accounts, fn
      {_platform, [{_, _} | _] = errors} -> errors
      {platform, accounts} -> Enum.map(accounts, &{platform, &1})
    end)
  end

  defp sort_platforms_by_order(accounts, order) when is_list(order) do
    all = Map.keys(accounts)
    ordered = Enum.filter(order, &(&1 in all))
    rest = Enum.sort(all -- ordered)

    Enum.map(ordered ++ rest, &{&1, Map.get(accounts, &1)})
  end

  defp sort_platforms_by_order(accounts, _) do
    accounts
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&{&1, Map.get(accounts, &1)})
  end

  defp get_attribute_value(attrs, key) do
    case List.keyfind(attrs, key, 0) do
      {^key, value} -> value
      nil -> nil
    end
  end
end
