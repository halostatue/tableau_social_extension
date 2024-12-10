defmodule TableauSocialExtension.PageCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ExUnit.Case, unquote(opts)

      import TableauSocialExtension.PageCase
    end
  end

  def process_page(page_body, opts \\ []) do
    page = build_page(page_body, Keyword.take(opts, [:permalink, :frontmatter_accounts]))

    config =
      opts
      |> Keyword.take([:css_prefix, :accounts, :show_errors, :platforms])
      |> build_config()

    result =
      TableauSocialExtension.pre_write(%{
        site: %{pages: [page], config: %{}},
        extensions: %{social_accounts: %{config: config}}
      })

    if Keyword.get(opts, :parse, true) do
      assert {:ok, %{site: %{pages: [%{body: body}]}}} = result
      Floki.parse_document!(body)
    else
      result
    end
  end

  def build_config(opts \\ []) do
    case TableauSocialExtension.config(Map.merge(%{enabled: true, accounts: %{}, show_errors: true}, Map.new(opts))) do
      {:ok, config} -> config
      {:error, reason} -> raise "Failed to build config: #{reason}"
    end
  end

  defp build_page(body, opts) do
    social_accounts =
      case Keyword.fetch(opts, :frontmatter_accounts) do
        {:ok, value} when is_map(value) ->
          Map.new(value, fn
            # Preserve list keys like ["include"]
            {k, v} when is_list(k) -> {k, v}
            # Convert string directive to list
            {"[include]", v} -> {["include"], v}
            # Convert string directive to list
            {"[order]", v} -> {["order"], v}
            # Convert other keys to strings
            {k, v} -> {to_string(k), v}
          end)

        {:ok, value} ->
          value

        :error ->
          %{}
      end

    page = %{
      body: body,
      permalink: Keyword.get(opts, :permalink, "/test")
    }

    if social_accounts == :omit do
      page
    else
      Map.put(page, :social_accounts, social_accounts)
    end
  end
end
