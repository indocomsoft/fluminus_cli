defmodule FluminusCLI.Work.ExternalMultimedia do
  @moduledoc "Handles external multimedia work"

  @behaviour FluminusCLI.Work

  import FluminusCLI.Constants
  import FluminusCLI.Util
  alias Fluminus.Authorization
  alias Fluminus.API.Module
  alias Fluminus.API.Module.ExternalMultimedia
  alias Fluminus.Util

  @impl true
  def option, do: :external_multimedia

  @impl true
  def short_doc, do: "Download external multimedia files too"

  @impl true
  def process_module(mod = %Module{code: code}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    {:ok, mms} = Module.external_multimedias(mod, auth)

    mms
    |> Enum.map(fn mm = %ExternalMultimedia{name: name} ->
      GenRetry.Task.async(
        fn ->
          destination =
            path
            |> Path.join(Util.sanitise_filename(code))
            |> Path.join("Multimedia")
            |> Path.join(Util.sanitise_filename(name))

          File.mkdir_p!(destination)

          {:ok, children} = ExternalMultimedia.get_children(mm, auth)

          children
          |> Enum.map(fn child ->
            GenRetry.Task.async(
              fn -> download(child, destination, verbose) end,
              gen_retry_options()
            )
          end)
          |> Enum.each(&Task.await(&1, :infinity))
        end,
        gen_retry_options()
      )
    end)
    |> Enum.each(&Task.await(&1, :infinity))
  end

  defp download(
         child = %ExternalMultimedia.Child{name: name},
         path,
         verbose
       ) do
    destination = Path.join(path, Util.sanitise_filename(name) <> ".mp4")

    tmp_destination = Path.join("/tmp", Util.sanitise_filename(name) <> ".mp4")

    if not File.exists?(destination) do
      {:ok, _} = File.rm_rf(tmp_destination)

      if verbose, do: IO.puts("Starting download of external multimedia #{destination}")
      :ok = ExternalMultimedia.Child.download(child, "/tmp", verbose)
      :ok = rename_wrapper(tmp_destination, destination)
      IO.puts("Downloaded to #{destination}")
    end
  end
end
