defmodule FailingUrlBuilder do
  @moduledoc false
  def build(_fields), do: {:error, "URL builder failed!"}
end

defmodule SuccessUrlBuilder do
  @moduledoc false
  def build(fields), do: {:ok, "https://success.com/#{fields["username"]}"}
end
