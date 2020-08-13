defmodule FluminusCLI.Work.Weblecture do
  @moduledoc "Handles webcast work"

  @behaviour FluminusCLI.Work

  import FluminusCLI.Constants
  import FluminusCLI.Util
  alias Fluminus.Authorization
  alias Fluminus.API.Module
  alias Fluminus.API.Module.Weblecture
  alias Fluminus.Util

  @impl true
  def option, do: :webcasts

  @impl true
  def short_doc, do: "Download files in the weekly lesson plans too"

  @impl true
  def process_module(mod = %Module{code: code}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Webcasts")
    File.mkdir_p!(destination)

    {:ok, weblectures} = Module.weblectures(mod, auth)

    weblectures
    |> Enum.map(fn weblecture = %Weblecture{name: name} ->
      GenRetry.Task.async(
        fn ->
          final_destination = Path.join(destination, "#{Util.sanitise_filename(name)}.mp4")
          tmp_destination = Path.join("/tmp", "#{Util.sanitise_filename(name)}.mp4")

          if not File.exists?(final_destination) do
            {:ok, _} = File.rm_rf(tmp_destination)
            if verbose, do: IO.puts("Starting download of webcast #{final_destination}")
            :ok = Weblecture.download(weblecture, auth, "/tmp", verbose)
            :ok = rename_wrapper(tmp_destination, final_destination)
            IO.puts("Downloaded to #{final_destination}")
          end
        end,
        gen_retry_options()
      )
    end)
    |> Enum.each(&Task.await(&1, :infinity))
  end
end
