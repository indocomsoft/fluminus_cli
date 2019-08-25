defmodule Mix.Tasks.Fluminus do
  @help """
  mix fluminus [OPTIONS]

  --verbose           Enable verbose mode

  --announcements     Show announcements
  --files             Show files
  --download-to=PATH  Download files to PATH
  --webcasts          Download webcasts too (only with --download-to)
  """

  @moduledoc """
  Runs the Fluminus CLI.

  ```
  #{@help}
  ```
  """

  @shortdoc "Runs the Fluminus CLI."

  use Mix.Task

  def run(args) do
    if "--help" in args or "-h" in args do
      IO.puts(@help)
    else
      FluminusCLI.run(args)
    end
  end
end
