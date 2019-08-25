defmodule FluminusCLI.NoOpLogger do
  @moduledoc """
  A GenRetry.Logger that simply swallows all the error messages.
  """
  @behaviour GenRetry.Logger

  @impl true
  def log(_) do
    text = "An error has occurred. Fluminus will automatically retry 10 times."
    IO.puts(text)
    text
  end
end
