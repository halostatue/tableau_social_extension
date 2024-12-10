defmodule TableauSocialExtension.Platform do
  @moduledoc """
  Behaviour for building social platform processing handlers.

  Simple social platforms (those with just a username) do not require handlers and are
  handled by internal functions, building account maps only with `username` keys, like
  `%{"username" => String.t()}`.

  More complex platforms use custom handlers for account parsing and filtering.

  ## Custom Handlers

  All handlers must implement the required callbacks:

  - `parse_account/1`: Convert account strings/maps to normalized account maps
    (`t:account/0`). This is used during configuration and for resolving dynamic
    `<a social-{platform}="key">` tags.

  - `filter_by_key/2`: Find accounts by key for `<a social-{platform}="key">` tags.

  - `keys/0`: The list of keys that the platform uses in account maps. The keys _must_ be
    strings and multi-word keys should be expressed in `kebab-case`.

  ### Optional Callbacks

  Handlers may implement:

  - `label/0`: Display name for the platform.

  - `url_template/0`: Template string with `{field}` placeholders for URL generation.
    Should not be defined if `url_builder/1` is defined.

  - `url_builder/1`: Function for complex URL generation (alternative to template). Should
    not be defined if `url_template/0` is defined.

  - `default_link_text/0`: Template string for default link text. Should not be defined if
    `default_link_text/1` is defined.

  - `default_link_text/1`: Function for complex link text generation. Should not be
    defined if `default_link_text/0` is defined.

  If the handler is used as the platform configuration value, then it must implement
  `label/0`, a URL builder (`url_template/0` or `url_builder/1`), and a link text provider
  (`default_link_text/0` or `default_link_text/1`).

  #### Templates and Field Substitution

  `url_template/0` and `default_link_text/0` return templates with `{field}` syntax where
  the `field` corresponds to keys in the `t:account/0` map returned by `parse_account/1`.
  Template fields which do not have a matching key will remain unmodified.

  **Examples**

  Assuming an account map of `%{"username" => "someuser"}`:

  - `https://example.com/{username}` becomes `https://example.com/someuser`
  - `https://{instance}/{username}` becomes `https://{instance}/someuser`

  ### Example

  ```elixir
  defmodule MyApp.CustomHandler do
    use TableauSocialExtension.Platform

    @impl Platform
    def label, do: "Custom Platform"

    @impl Platform
    def url_template, do: "https://custom.example.com/{username}"

    @impl Platform
    def parse_account(account) when is_binary(account) do
      {:ok, %{"username" => account}}
    end

    @impl Platform
    def parse_account(%{"username" => username}) do
      {:ok, %{"username" => username}}
    end

    @impl Platform
    def filter_by_key(accounts, key) do
      case Enum.find(accounts, &(&1["username"] == username)) do
        nil -> {:error, "No account found for username " <> username}
        account -> {:ok, account}
      end
    end
  end
  ```
  """

  @typedoc """
  An account map.

  always using string keys and simple scalar values.

  The account map must have `t:String.t/0` keys (and _should_ be kebab-case) with simple
  scalar values. This map will be used for URL building (`url_template/0` or
  `url_builder/1`) and social link selection (`filter_by_key/2`).
  """
  @type account :: %{String.t() => String.t() | number() | boolean() | atom()}

  @typedoc """
  An account result, either `{:ok, account()}`, `:error`, or `{:error, reason}`.
  """
  @type account_result :: {:ok, account()} | :error | {:error, String.t()}

  @doc """
  The name of the handler, always created when the module is `use`d.
  """
  @callback name() :: String.t()

  @doc """
  The list of keys that the platform uses in account maps. The keys _must_ be strings and
  multi-word keys _should_ be expressed in `kebab-case`.
  """
  @callback keys() :: [String.t()]

  @doc """
  Parse an account string or map into an account map.

  This callback is used when processing platform account configuration and frontmatter
  configuration to prepare accounts for processing later.
  """
  @callback parse_account(String.t() | map()) :: account_result()

  @doc """
  Filters configured platform accounts by the provided `key` against identifying values of
  the platform account map.

  This callback is used when processing `<a social-{platform}="value">` tags to find
  matching accounts from the configured platform accounts list.
  """
  @callback filter_by_key(accounts :: [String.t() | map()], key :: String.t()) :: account_result()

  @doc "Optional display label for this platform."
  @callback label() :: String.t()

  @doc """
  Optional URL template with `{field}` placeholders.

  The template should use `{field}` syntax for field substitution, where `field`
  corresponds to keys in the map returned by `parse_account/1`.

  Must not be implemented if `url_builder/1` is implemented.
  """
  @callback url_template() :: String.t()

  @doc """
  Optional function to build a URL from a `parse_account/1` map.

  This callback provides maximum flexibility for complex URL generation that cannot be
  expressed with simple template substitution.

  Must not be implemented if `url_template/0` is implemented.
  """
  @callback url_builder(fields :: %{String.t() => String.t()}) :: {:ok, String.t()} | {:error, String.t()} | :error

  @doc """
  Optional template string for generating default link text with `{field}` placeholders.

  The template should use `{field}` syntax for field substitution, where `field`
  corresponds to keys in the map returned by `parse_account/1`.

  Must not be implemented if `default_link_text/1` is implemented.
  """
  @callback default_link_text() :: String.t()

  @doc """
  Optional function to generate default link text from a parsed account map.

  This callback provides maximum flexibility for complex link text generation that cannot
  be expressed with simple template substitution.

  Must not be implemented if `default_link_text/0` is implemented.
  """
  @callback default_link_text(fields :: %{String.t() => String.t()}) ::
              {:ok, String.t()} | {:error, String.t()} | :error

  @optional_callbacks label: 0,
                      url_template: 0,
                      url_builder: 1,
                      default_link_text: 0,
                      default_link_text: 1

  @doc false
  @spec parse_account(
          platform :: String.t(),
          account :: String.t() | map(),
          handler :: nil | module()
        ) :: account_result()
  def parse_account(platform, "@" <> account, handler) do
    parse_account(platform, account, handler)
  end

  def parse_account(platform, "", _handler) do
    {:error, "#{platform} accounts must not be empty strings"}
  end

  def parse_account(_platform, %{"username" => username}, nil) do
    {:ok, %{"username" => username}}
  end

  def parse_account(_platform, %{username: username}, nil) do
    {:ok, %{"username" => username}}
  end

  def parse_account(platform, account, nil) when is_map(account) do
    {:error, "#{platform} account maps must contain 'username' key"}
  end

  def parse_account(_platform, account, nil) when is_binary(account) do
    {:ok, %{"username" => account}}
  end

  def parse_account(platform, account, handler) do
    case handler.parse_account(account) do
      {:ok, parsed} ->
        {:ok, Map.new(parsed, fn {k, v} -> {to_string(k), v} end)}

      :error ->
        {:error, "#{platform} handler #{handler.name()} failed to parse account #{inspect(account)}"}

      {:error, reason} ->
        {:error, "#{platform} handler #{handler.name()} failed to parse account #{inspect(account)}: #{reason}"}
    end
  end

  @doc false
  @spec build_url(
          platform :: String.t(),
          account :: account(),
          platforms :: %{String.t() => map()}
        ) :: {:ok, String.t()} | {:error, String.t()}
  def build_url(platform, account, platforms) do
    case Map.get(platforms, platform) do
      %{url_builder: {_, _, _} = mfa} -> build_url_with_builder(platform, account, mfa)
      %{url_template: template} -> substitute_template_fields(template, account)
      nil -> {:error, "Unknown platform: #{platform}"}
    end
  end

  @doc false
  @spec link_content(
          text :: nil | list(),
          platform :: String.t(),
          account :: account(),
          platforms :: %{String.t() => map()}
        ) :: term()
  def link_content(text \\ nil, platform, account, platforms)

  def link_content(value, platform, account, platforms) when value in ["", nil, []] do
    case get_in(platforms, [platform, :default_link_text]) do
      {module, function, args} -> apply(module, function, [account | args])
      template when is_binary(template) -> substitute_template_fields(template, account)
      nil -> Map.fetch(account, "username")
    end
  end

  def link_content(content, _platform, _account, _platforms) when is_binary(content) or is_list(content) do
    {:ok, content}
  end

  @doc false
  @spec substitute_template_fields(String.t(), map()) :: {:ok, String.t()}
  def substitute_template_fields(template, field_map) do
    {:ok, Enum.reduce(field_map, template, fn {k, v}, url -> String.replace(url, "{#{k}}", v) end)}
  end

  @doc false
  @spec __metadata__(nil | module()) :: %{
          optional(:label) => String.t(),
          optional(:url_template) => String.t(),
          optional(:url_builder) => {module(), atom(), list()},
          optional(:default_link_text) => String.t() | {module(), atom(), list()},
          handler: nil | module(),
          keys: [String.t()]
        }
  def __metadata__(nil) do
    %{handler: nil, keys: ["username"]}
  end

  def __metadata__(handler) do
    Code.ensure_loaded(handler)

    %{handler: handler, keys: handler.keys()}
    |> set_metadata(:label, 0)
    |> set_metadata(:url_template, 0)
    |> set_metadata(:url_builder, 1)
    |> set_metadata(:default_link_text, 0)
    |> set_metadata(:default_link_text, 1)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour TableauSocialExtension.Platform

      alias TableauSocialExtension.Platform

      @after_compile Platform

      def name, do: Macro.to_string(__MODULE__)
    end
  end

  # coveralls-ignore-start

  @doc false
  def __after_compile__(env, _bytecode) do
    if Module.defines?(env.module, {:url_template, 0}) and
         Module.defines?(env.module, {:url_builder, 1}) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "Handler #{inspect(env.module)} implements both " <>
            "url_template/0 and url_builder/1. Only one URL building method should " <>
            "be implemented. url_builder/1 takes precedence if both are present, " <>
            "but this is ambiguous and not allowed."
    end

    if Module.defines?(env.module, {:default_link_text, 0}) and
         Module.defines?(env.module, {:default_link_text, 1}) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "Handler #{inspect(env.module)} implements both " <>
            "default_link_text/0 and default_link_text/1. Only one link text method " <>
            "should be implemented. default_link_text/1 takes precedence if " <>
            "both are present, but this is ambiguous and not allowed."
    end
  end

  # coveralls-ignore-stop

  defp set_metadata(metadata, type, arity) do
    case {function_exported?(metadata.handler, type, arity), arity} do
      {false, _} -> metadata
      {true, 0} -> Map.put(metadata, type, apply(metadata.handler, type, []))
      {true, _} -> Map.put(metadata, type, {metadata.handler, type, []})
    end
  end

  defp build_url_with_builder(platform, account, {module, function, args} = mfa) do
    case apply(module, function, [account | args]) do
      {:ok, url} ->
        {:ok, url}

      :error ->
        {:error, "#{platform} URL could not be built for account #{inspect(account)} with #{format_mfa(mfa)}"}

      {:error, reason} ->
        {:error,
         "#{platform} URL could not be built for account #{inspect(account)} with #{format_mfa(mfa)}: #{reason}"}
    end
  end

  defp format_mfa({module, function, args}) do
    "#{Macro.to_string(module)}.#{function}/#{1 + length(args)}"
  end
end
