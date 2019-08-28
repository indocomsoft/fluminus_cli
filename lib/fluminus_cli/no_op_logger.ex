defmodule FluminusCLI.NoOpLogger do
  @moduledoc """
  A GenRetry.Logger that simply swallows all the error messages.
  """

  alias FluminusCLI.Constants

  require Logger

  @behaviour GenRetry.Logger

  @impl true
  def log(e) do
    case :ets.lookup(Constants.ets_table_name(), :show_errors) do
      [{:show_errors, true}] -> Logger.error(e)
      [{:show_errors, _}] -> nil
    end

    ""
  end
end
