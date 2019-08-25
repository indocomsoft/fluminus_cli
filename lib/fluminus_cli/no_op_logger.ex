defmodule FluminusCLI.NoOpLogger do
  @moduledoc """
  A GenRetry.Logger that simply swallows all the error messages.
  """
  @behaviour GenRetry.Logger

  @impl true
  def log(_) do
    IO.puts("An error has occurred. Fluminus will automatically retry 10 times.")
  end
end
