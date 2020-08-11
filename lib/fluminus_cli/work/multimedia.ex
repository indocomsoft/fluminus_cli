defmodule FluminusCLI.Work.Multimedia do
  @moduledoc "Handles multimedia work"

  @behaviour FluminusCLI.Work

  import FluminusCLI.Constants
  alias Fluminus.Authorization
  alias Fluminus.API.Module
  alias Fluminus.API
  alias Fluminus.Util

  require Logger

  @impl true
  def option, do: :multimedia

  @impl true
  def short_doc, do: "Download unanchored multimedia files too"

  @impl true
  def process_module(mod = %Module{code: code}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Multimedia")

    {:ok, files} = Module.multimedias(mod, auth)

    files
    |> Enum.map(fn file ->
      GenRetry.Task.async(
        fn ->
          case API.File.load_children(file, auth) do
            {:ok, loaded_file} ->
              FluminusCLI.Work.File.download(loaded_file, auth, destination, verbose)

            {:error, :forbidden} ->
              Logger.error("#{code} multimedia channel #{file.name} is forbidden, skipping...")
          end
        end,
        gen_retry_options()
      )
    end)
    |> Enum.each(&Task.await(&1, :infinity))
  end
end
