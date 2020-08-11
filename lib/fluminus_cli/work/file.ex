defmodule FluminusCLI.Work.File do
  @moduledoc """
  Does not implement behaviour FluminusCLI.Work because this is the main work of download_to
  """

  import FluminusCLI.Constants
  import FluminusCLI.Util
  alias Fluminus.API
  alias Fluminus.API.Module
  alias Fluminus.Authorization

  def process_module(mod = %Module{}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    {:ok, file} = API.File.from_module(mod, auth)

    download(file, auth, path, verbose)
  end

  @spec download(API.File.t(), Authorization.t(), String.t(), bool()) :: any()
  def download(file = %API.File{}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    destination = Path.join(path, file.name)

    if file.directory? do
      File.mkdir_p!(destination)

      file.children
      |> Enum.map(fn child ->
        GenRetry.Task.async(
          fn ->
            {:ok, child} = API.File.load_children(child, auth)
            download(child, auth, destination, verbose)
          end,
          gen_retry_options()
        )
      end)
      |> Enum.each(&Task.await(&1, :infinity))
    else
      download_file_wrapper(file, path, auth, verbose)
    end
  end
end
