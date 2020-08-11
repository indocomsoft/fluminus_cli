defmodule Mix.Tasks.Fluminus do
  @help """
  mix fluminus [OPTIONS]

  --verbose             Enable verbose mode
  --show-errors         Show all errors instead of just swallowing them

  --announcements       Show announcements
  --files               Show files
  --download-to=PATH    Download files to PATH

  Only with --download-to
  """

  @moduledoc """
  Runs the Fluminus CLI.

  For more information, run: `mix fluminus --help`
  """

  @shortdoc "Runs the Fluminus CLI."

  use Mix.Task

  def run(args) do
    if "--help" in args or "-h" in args do
      IO.puts(@help <> download_to_help())
    else
      FluminusCLI.run(args)
    end
  end

  def download_to_help do
    kv =
      Enum.map(FluminusCLI.Work.all_work(), fn work ->
        option = work.option() |> to_string() |> String.replace("_", "-")
        {"--#{option}", work.short_doc()}
      end)

    max_length = kv |> Enum.map(fn {k, _} -> String.length(k) end) |> Enum.max()

    kv
    |> Enum.map(fn {k, v} ->
      String.pad_trailing(k, max_length + 2) <> v
    end)
    |> Enum.join("\n")
  end
end
