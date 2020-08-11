defmodule FluminusCLI.Constants do
  @moduledoc false

  def ets_table_name, do: :fluminus_cli

  def gen_retry_options, do: [retries: :infinity, delay: 0, exp_base: 1]
end
