defmodule FluminusCLI.NoOpLogger do
  @moduledoc """
  A GenRetry.Logger that simply swallows all the error messages.
  """
  @behaviour GenRetry.Logger

  @impl true
  def log(_), do: ""
end
