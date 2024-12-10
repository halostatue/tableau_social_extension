alias TableauSocialExtension.Platform

defmodule InvalidHandler do
  @moduledoc false

  use Platform

  @impl Platform
  def parse_account(account), do: {:ok, %{"name" => account}}

  @impl Platform
  def filter_by_key(_accounts, account), do: {:ok, %{"name" => account}}

  @impl Platform
  def keys, do: ["name"]
end

defmodule WorkingHandler do
  @moduledoc false
  use Platform

  @impl Platform
  def parse_account(account), do: {:ok, %{"name" => account}}

  @impl Platform
  def filter_by_key(_accounts, account), do: {:ok, %{"name" => account}}

  @impl Platform
  def keys, do: ["name"]

  @impl Platform
  def label, do: "Working Platform"

  @impl Platform
  def url_template, do: "https://working.com/{name}"
end

defmodule FailingHandler do
  @moduledoc false
  use Platform

  @impl Platform
  def parse_account(account) when is_binary(account), do: {:error, "Parse failed!"}

  def parse_account(account) when is_map(account), do: :error

  @impl Platform
  def filter_by_key(_accounts, _key), do: {:error, "Filter failed!"}

  @impl Platform
  def label, do: "Failing Platform"

  @impl Platform
  def keys, do: ["name"]

  @impl Platform
  def url_template, do: "https://example.com/{name}"
end

defmodule NoLabelHandler do
  @moduledoc false
  use Platform

  @impl Platform
  def parse_account(account), do: {:ok, %{"name" => account}}

  @impl Platform
  def filter_by_key(_accounts, account), do: {:ok, %{"name" => account}}

  @impl Platform
  def keys, do: ["name"]

  @impl Platform
  def url_template, do: "https://example.com/{name}"
end

defmodule NoUrlHandler do
  @moduledoc false
  use Platform

  @impl Platform
  def parse_account(account), do: {:ok, %{"name" => account}}

  @impl Platform
  def filter_by_key(_accounts, account), do: {:ok, %{"name" => account}}

  @impl Platform
  def keys, do: ["name"]

  @impl Platform
  def label, do: "NoUrlHandler"
end
