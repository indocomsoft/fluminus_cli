defmodule FluminusCLI.Util do
  @moduledoc """
  Contains various utilities used by work
  """

  alias Fluminus.API
  alias Fluminus.Authorization

  require Logger

  @spec rename_wrapper(Path.t(), Path.t()) :: :ok | {:error, Elixir.File.posix()}
  def rename_wrapper(source, destination) do
    case Elixir.File.rename(source, destination) do
      {:error, :exdev} ->
        with :ok <- Elixir.File.cp(source, destination),
             :ok <- Elixir.File.rm(source) do
          :ok
        else
          error -> error
        end

      x ->
        x
    end
  end

  @spec download_file_wrapper(
          API.File.t(),
          Path.t(),
          Authorization.t(),
          boolean()
        ) :: :ok
  def download_file_wrapper(
        file = %API.File{},
        path,
        auth = %Authorization{},
        verbose
      )
      when is_boolean(verbose) do
    destination = Path.join(path, file.name)
    tmp_destination = Path.join("/tmp", file.name)

    if not File.exists?(destination) do
      {:ok, _} = File.rm_rf(tmp_destination)

      if verbose, do: IO.puts("Starting download of file #{destination}")

      case API.File.download(file, auth, "/tmp", verbose) do
        :ok ->
          :ok = rename_wrapper(tmp_destination, destination)
          IO.puts("Downloaded to #{destination}")

        {:error, {:unexpected_response, %{"fileFormat" => "Weblink"}}} ->
          Logger.error("Multimedia #{destination} is a weblink, skipping...")

        {:error, :processing} ->
          Logger.error("Multimedia #{destination} is still processing, skipping...")

        {:error, :noffmpeg} ->
          IO.puts("Missing ffmpeg, unable to download multimedia file.")
      end
    end
  end
end
