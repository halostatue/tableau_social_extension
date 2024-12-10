defmodule TableauSocialExtension.Render do
  @moduledoc false

  require Logger

  def ensure_attribute_value_list(attrs, key, required) do
    case current_value_list(attrs, key) do
      nil -> [{key, merge_value_list(required)} | attrs]
      current -> List.keyreplace(attrs, key, 0, {key, merge_value_list(current, required)})
    end
  end

  def merge_value_list(current \\ nil, required) do
    current
    |> List.wrap()
    |> Enum.concat(required)
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  # Renders configuration errors based on context and configuration.
  #
  # - For blocks with show_errors: false - logs errors and returns empty string
  # - For blocks with show_errors: true - renders styled error display
  # - For links with show_errors: false - logs errors and returns empty string
  # - For links with show_errors: true - renders clickable span with error details
  def render_errors([], _config, _context), do: ""

  def render_errors(errors, %{show_errors: false} = config, _context) do
    log_errors(errors, config)
    ""
  end

  def render_errors(error, config, context) when not is_list(error), do: render_errors([error], config, context)

  def render_errors(errors, config, :block) do
    render_block_errors(errors, config)
  end

  def render_errors(errors, config, :link) do
    render_link_errors(errors, config)
  end

  def render_no_accounts_error(%{show_errors: false} = config) do
    log_errors(["No social accounts configured"], config)
    ""
  end

  def render_no_accounts_error(config) do
    render_block_errors(["No social accounts configured"], config)
  end

  defp render_block_errors(errors, config) do
    error_count = length(errors)
    error_items = Enum.map(errors, &render_error_item/1)
    debug_info = render_debug_info(config)

    {"div",
     [
       {"class", "social-error"},
       {"style",
        "border: 3px solid; border-image: repeating-linear-gradient(45deg, #ffcc00 0px, #ffcc00 10px, #000000 10px, #000000 20px) 1; padding: 12px; margin: 8px 0; background: var(--color-error-bg, rgba(255, 255, 255, 0.95)); border-radius: 4px; font-family: monospace; color: var(--color-error-text, currentColor)"}
     ],
     [
       {"strong", [{"style", "color: var(--color-error-accent, #dc3545)"}],
        ["Social Accounts Configuration Errors (#{error_count})"]},
       {"ul", [{"style", "margin: 8px 0; padding-left: 20px"}], error_items},
       {"details", [{"style", "margin-top: 8px"}],
        [
          {"summary", [{"style", "cursor: pointer; color: var(--color-error-accent, #dc3545)"}], ["Debug Information"]},
          {"pre",
           [
             {"style",
              "margin: 8px 0; padding: 8px; background: var(--color-error-code-bg, rgba(0, 0, 0, 0.05)); border-radius: 3px; font-size: 12px; color: var(--color-error-code-text, currentColor)"}
           ], [debug_info]}
        ]}
     ]}
  end

  defp render_link_errors(errors, config) do
    error_count = length(errors)
    error_items = Enum.map(errors, &render_error_item/1)
    debug_info = render_debug_info(config)

    {"details",
     [
       {"class", "social-error-link"},
       {"style",
        "display: inline-block; font-family: monospace; margin: 4px 0; position: relative; vertical-align: top;"}
     ],
     [
       {"summary",
        [
          {"style",
           "display: inline-block; cursor: pointer; color: var(--color-error-accent, #dc3545); text-decoration: none; font-weight: bold; padding: 2px 6px; border-radius: 3px; background: var(--color-error-bg, rgba(220, 53, 69, 0.1)); list-style: none;"}
        ], ["▶ Social Error"]},
       {"div",
        [
          {"style",
           "position: absolute; top: 100%; left: 0; z-index: 1000; border: 3px solid; border-image: repeating-linear-gradient(45deg, #ffcc00 0px, #ffcc00 10px, #000000 10px, #000000 20px) 1; padding: 12px; margin: 4px 0; background: var(--color-error-bg, rgba(255, 255, 255, 0.95)); border-radius: 4px; font-family: monospace; color: var(--color-error-text, currentColor); min-width: 300px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);"}
        ],
        [
          {"strong", [{"style", "color: var(--color-error-accent, #dc3545)"}],
           ["Social Link Configuration Errors (#{error_count})"]},
          {"ul", [{"style", "margin: 8px 0; padding-left: 20px"}], error_items},
          {"details", [{"style", "margin-top: 8px"}],
           [
             {"summary", [{"style", "cursor: pointer; color: var(--color-error-accent, #dc3545)"}],
              ["Debug Information"]},
             {"pre",
              [
                {"style",
                 "margin: 8px 0; padding: 8px; background: var(--color-error-code-bg, rgba(0, 0, 0, 0.05)); border-radius: 3px; font-size: 12px; color: var(--color-error-code-text, currentColor)"}
              ], [debug_info]}
           ]}
        ]}
     ]}
  end

  defp log_errors(errors, config) do
    errors_text =
      errors
      |> List.wrap()
      |> Enum.map_join("\n  ", &format_error_for_log/1)

    permalink = Map.get(config, :permalink, "unknown")
    Logger.warning("Social extension errors on page #{permalink}:\n  #{errors_text}")
  end

  defp format_error_for_log({platform, message}), do: "#{platform}: #{message}"
  defp format_error_for_log(message) when is_binary(message), do: message

  defp current_value_list(attrs, key) do
    case List.keyfind(attrs, key, 0) do
      {^key, existing} -> String.split(existing, " ", trim: true)
      nil -> nil
    end
  end

  defp render_error_item({platform, message}), do: {"li", [], [{"strong", [], ["#{platform}:"]}, " #{message}"]}

  defp render_error_item(message) when is_binary(message), do: {"li", [], [message]}

  defp render_debug_info(config) do
    accounts = Enum.map_join(config.accounts, ", ", fn {k, v} -> "#{k} (#{length(v)})" end)

    """
    Platforms: #{Enum.map_join(config.platforms, ", ", &elem(&1, 0))}
    Accounts: #{accounts}
    """
  end
end
