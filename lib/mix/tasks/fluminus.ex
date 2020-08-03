defmodule Mix.Tasks.Fluminus do
  @help """
  mix fluminus [OPTIONS]

  --verbose           Enable verbose mode
  --show-errors       Show all errors instead of just swallowing them

  --announcements     Show announcements
  --files             Show files
  --download-to=PATH  Download files to PATH

  Only with --download-to
  --webcasts          Download webcasts too
  --lessons           Download files in the weekly lesson plans too
  --multimedia        Download unanchored multimedia files too
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
