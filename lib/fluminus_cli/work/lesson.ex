defmodule FluminusCLI.Work.Lesson do
  @moduledoc "Handles lesson plans work"

  @behaviour FluminusCLI.Work

  import FluminusCLI.Constants
  import FluminusCLI.Util
  alias Fluminus.Authorization
  alias Fluminus.API.Module
  alias Fluminus.API.Module.Lesson
  alias Fluminus.Util

  @impl true
  def option, do: :lessons

  @impl true
  def short_doc, do: "Download files in the weekly lesson plans too"

  @impl true
  def process_module(mod = %Module{code: code}, auth = %Authorization{}, path, verbose)
      when is_binary(path) and is_boolean(verbose) do
    {:ok, lessons} = Module.lessons(mod, auth)

    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Lessons")
    Elixir.File.mkdir_p!(destination)

    lessons
    |> Enum.map(fn lesson = %Lesson{name: name, week: week} ->
      GenRetry.Task.async(
        fn ->
          dir_name = Util.sanitise_filename("#{week} - #{name}")
          lesson_destination = Path.join(destination, dir_name)
          Elixir.File.mkdir_p!(lesson_destination)

          {:ok, files} = Lesson.files(lesson, auth)

          files
          |> Enum.map(fn file ->
            GenRetry.Task.async(
              fn -> download_file_wrapper(file, lesson_destination, auth, verbose) end,
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
end
