defmodule FluminusCLI do
  @moduledoc """
  Provides functions related to Fluminus' CLI.
  """

  @config_file "config.json"

  @gen_retry_options [retries: :infinity, delay: 0, exp_base: 1]

  alias Fluminus.API.{File, Module}
  alias Fluminus.API.Module.{ExternalMultimedia, Lesson, Weblecture}
  alias Fluminus.{Authorization, Util}
  alias FluminusCLI.Constants

  require Logger

  def run(args) do
    initialise()

    {username, password} = load_credentials()

    case Authorization.vafs_jwt(username, password) do
      {:ok, auth} ->
        save_credentials(username, password)
        run(args, auth)

      {:error, :invalid_credentials} ->
        IO.puts("Invalid credentials!")
        clear_credentials()
        run(args)

      {:error, error} ->
        IO.puts("Error: #{inspect(error)}")
        IO.puts("Retrying")
        run(args)
    end
  end

  defp initialise do
    Application.ensure_all_started(:ets)
    :ets.new(Constants.ets_table_name(), [:named_table])

    HTTPoison.start()
  end

  @spec run([String.t()], Authorization.t()) :: :ok
  defp run(args, auth = %Authorization{}) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          announcements: :boolean,
          files: :boolean,
          download_to: :string,
          lessons: :boolean,
          webcasts: :boolean,
          verbose: :boolean,
          show_errors: :boolean,
          multimedia: :boolean,
          external_multimedia: :boolean
        ]
      )

    {:ok, name} = Fluminus.API.name(auth)
    IO.puts("Hi #{name}")
    {:ok, modules} = Fluminus.API.modules(auth, true)
    IO.puts("You are taking:")
    modules |> Enum.filter(&(not &1.teaching?)) |> Enum.each(&IO.puts("- #{&1.code} #{&1.name}"))
    IO.puts("And teaching:")
    modules |> Enum.filter(& &1.teaching?) |> Enum.each(&IO.puts("- #{&1.code} #{&1.name}"))
    IO.puts("")

    parsed_map = Enum.into(parsed, %{})

    # TODO use GenServer instead
    :ets.insert(Constants.ets_table_name(), {:show_errors, parsed_map[:show_errors]})

    if parsed_map[:announcements], do: list_announcements(auth, modules)
    if parsed_map[:files], do: list_files(auth, modules)

    if parsed_map[:download_to] do
      path = parsed_map[:download_to]
      lessons = parsed_map[:lessons]
      webcasts = parsed_map[:webcasts]
      multimedia = parsed_map[:multimedia]
      external_multimedia = parsed_map[:external_multimedia]
      verbose = parsed_map[:verbose]

      download_to(
        auth,
        modules,
        path,
        verbose,
        lessons,
        webcasts,
        multimedia,
        external_multimedia
      )
    end
  end

  defp download_to(
         auth,
         modules,
         path,
         verbose,
         include_lessons,
         include_webcasts,
         include_multimedia,
         include_external_multimedia
       ) do
    IO.puts("Download to #{path}")

    if Elixir.File.exists?(path) do
      modules
      |> Enum.map(fn mod ->
        GenRetry.Task.async(
          fn ->
            file_task =
              GenRetry.Task.async(
                fn ->
                  {:ok, file} = File.from_module(mod, auth)
                  tasks = download_file(file, auth, path, verbose)
                  Enum.each(tasks, &Task.await(&1, :infinity))
                end,
                @gen_retry_options
              )

            lesson_files_task =
              if include_lessons do
                GenRetry.Task.async(
                  fn ->
                    {:ok, lessons} = Module.lessons(mod, auth)
                    tasks = download_lesson_files(lessons, mod, auth, path, verbose)
                    Enum.each(tasks, &Task.await(&1, :infinity))
                  end,
                  @gen_retry_options
                )
              end

            webcast_task =
              if include_webcasts do
                GenRetry.Task.async(
                  fn ->
                    {:ok, webcasts} = Module.weblectures(mod, auth)
                    tasks = download_webcasts(webcasts, auth, mod, path, verbose)
                    Enum.each(tasks, &Task.await(&1, :infinity))
                  end,
                  @gen_retry_options
                )
              end

            external_multimedia_task =
              if include_external_multimedia do
                GenRetry.Task.async(
                  fn ->
                    {:ok, mms} = Module.external_multimedias(mod, auth)
                    tasks = download_external_multimedias(mms, auth, mod, path, verbose)
                    Enum.each(tasks, &Task.await(&1, :infinity))
                  end,
                  @gen_retry_options
                )
              end

            multimedia_task =
              if include_multimedia do
                GenRetry.Task.async(
                  fn ->
                    {:ok, files} = Module.multimedias(mod, auth)

                    files =
                      Enum.map(files, fn file ->
                        case File.load_children(file, auth) do
                          {:ok, loaded_file} ->
                            loaded_file

                          {:error, :forbidden} ->
                            Logger.error(
                              "#{mod.code} multimedia channel #{file.name} is forbidden, skipping..."
                            )

                            %File{file | children: []}
                        end
                      end)

                    tasks = download_multimedias(files, auth, mod, path, verbose)
                    Enum.each(tasks, &Task.await(&1, :infinity))
                  end,
                  @gen_retry_options
                )
              end

            [
              file_task,
              lesson_files_task,
              webcast_task,
              multimedia_task,
              external_multimedia_task
            ]
            |> Enum.filter(&(&1 != nil))
            |> Enum.each(&Task.await(&1, :infinity))
          end,
          @gen_retry_options
        )
      end)
      |> Enum.each(&Task.await(&1, :infinity))
    else
      IO.puts("Download destination does not exist!")
    end
  end

  defp download_multimedias(
         files,
         auth = %Authorization{},
         %Module{code: code},
         path,
         verbose
       )
       when is_list(files) do
    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Multimedia")

    Enum.flat_map(files, &download_file(&1, auth, destination, verbose))
  end

  defp download_external_multimedias(
         mms,
         auth = %Authorization{},
         %Module{code: code},
         path,
         verbose
       )
       when is_list(mms) do
    Enum.map(mms, fn mm = %ExternalMultimedia{name: name} ->
      destination =
        path
        |> Path.join(Util.sanitise_filename(code))
        |> Path.join("Multimedia")
        |> Path.join(Util.sanitise_filename(name))

      Elixir.File.mkdir_p!(destination)

      GenRetry.Task.async(
        fn ->
          {:ok, children} = ExternalMultimedia.get_children(mm, auth)

          children
          |> Enum.map(fn child ->
            GenRetry.Task.async(
              fn -> download_external_multimedia_wrapper(child, destination, verbose) end,
              @gen_retry_options
            )
          end)
          |> Enum.each(&Task.await(&1, :infinity))
        end,
        @gen_retry_options
      )
    end)
  end

  defp download_external_multimedia_wrapper(
         child = %ExternalMultimedia.Child{name: name},
         path,
         verbose
       ) do
    destination = Path.join(path, Util.sanitise_filename(name) <> ".mp4")

    tmp_destination = Path.join("/tmp", Util.sanitise_filename(name) <> ".mp4")

    if not Elixir.File.exists?(destination) do
      Elixir.File.rm_rf!(tmp_destination)

      case ExternalMultimedia.Child.download(child, "/tmp", verbose) do
        :ok ->
          rename_wrapper(tmp_destination, destination)
          IO.puts("Downloaded to #{destination}")
      end
    end
  end

  defp download_webcasts(webcasts, auth = %Authorization{}, %Module{code: code}, path, verbose)
       when is_list(webcasts) do
    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Webcasts")
    Elixir.File.mkdir_p!(destination)

    Enum.map(webcasts, fn webcast = %Weblecture{name: name} ->
      GenRetry.Task.async(
        fn -> download_webcast_wrapper(webcast, auth, destination, name, verbose) end,
        @gen_retry_options
      )
    end)
  end

  defp download_webcast_wrapper(
         webcast = %Weblecture{},
         auth = %Authorization{},
         destination,
         name,
         verbose
       )
       when is_binary(name) do
    webcast_final_destination = Path.join(destination, "#{Util.sanitise_filename(name)}.mp4")

    webcast_tmp_destination = Path.join("/tmp", "#{Util.sanitise_filename(name)}.mp4")

    if not Elixir.File.exists?(webcast_final_destination) do
      Elixir.File.rm_rf!(webcast_tmp_destination)

      if verbose, do: IO.puts("Starting download of webcast #{name}")

      case Weblecture.download(webcast, auth, "/tmp", verbose) do
        :ok ->
          rename_wrapper(webcast_tmp_destination, webcast_final_destination)
          IO.puts("Downloaded to #{webcast_final_destination}")
      end
    end
  end

  defp download_lesson_files(
         lessons,
         %Module{code: code},
         auth = %Authorization{},
         path,
         verbose
       )
       when is_list(lessons) do
    destination = path |> Path.join(Util.sanitise_filename(code)) |> Path.join("Lessons")

    Elixir.File.mkdir_p!(destination)

    Enum.map(lessons, &download_lesson_files(&1, auth, verbose, destination))
  end

  defp download_lesson_files(
         lesson = %Lesson{name: name, week: week},
         auth = %Authorization{},
         verbose,
         destination
       )
       when is_boolean(verbose) do
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
            @gen_retry_options
          )
        end)
        |> Enum.each(&Task.await(&1, :infinity))
      end,
      @gen_retry_options
    )
  end

  @spec download_file_wrapper(
          File.t(),
          Path.t(),
          Authorization.t(),
          boolean(),
          (() -> any())
        ) ::
          :ok
  defp download_file_wrapper(
         file = %File{},
         path,
         auth = %Authorization{},
         verbose,
         pre_download \\ fn -> nil end
       )
       when is_boolean(verbose) do
    destination = Path.join(path, file.name)
    tmp_destination = Path.join("/tmp", file.name)

    if not Elixir.File.exists?(destination) do
      Elixir.File.rm_rf!(tmp_destination)

      pre_download.()

      case File.download(file, auth, "/tmp", verbose) do
        :ok ->
          rename_wrapper(tmp_destination, destination)
          IO.puts("Downloaded to #{destination}")

        {:error, :noffmpeg} ->
          IO.puts("Missing ffmpeg, unable to download multimedia file.")
      end
    end
  end

  @spec rename_wrapper(Path.t(), Path.t()) :: :ok | {:error, Elixir.File.posix()}
  defp rename_wrapper(source, destination) do
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

  defp download_file(file = %File{}, auth = %Authorization{}, path, verbose, tasks \\ []) do
    destination = Path.join(path, file.name)

    if file.directory? do
      Elixir.File.mkdir_p!(destination)

      file.children
      |> Enum.map(fn child ->
        GenRetry.Task.async(
          fn ->
            {:ok, child} = File.load_children(child, auth)
            child
          end,
          @gen_retry_options
        )
      end)
      |> Enum.reduce(tasks, fn task, acc ->
        child = Task.await(task, :infinity)
        download_file(child, auth, destination, verbose, acc)
      end)
    else
      task =
        GenRetry.Task.async(
          fn -> download_file_wrapper(file, path, auth, verbose) end,
          @gen_retry_options
        )

      [task | tasks]
    end
  end

  defp list_files(auth, modules) do
    IO.puts("\n# Files:\n")

    modules
    |> Enum.map(fn mod ->
      task =
        GenRetry.Task.async(
          fn ->
            {:ok, file} = File.from_module(mod, auth)
            file
          end,
          @gen_retry_options
        )

      {mod, task}
    end)
    |> Enum.each(fn {mod, task} ->
      file = Task.await(task, :infinity)

      IO.puts("## #{mod.code} #{mod.name}")
      list_file(file, auth)
      IO.puts("")
    end)
  end

  defp list_announcements(auth, modules) do
    IO.puts("\n# Announcements:\n")

    for mod <- modules do
      IO.puts("## #{mod.code} #{mod.name}")

      {:ok, announcements} = Fluminus.API.Module.announcements(mod, auth)

      for %{title: title, description: description} <- announcements do
        IO.puts("=== #{title} ===")
        IO.puts(description)
      end

      IO.puts("")
    end
  end

  @spec load_credentials :: {String.t(), String.t()}
  defp load_credentials do
    with {:ok, data} <- Elixir.File.read(@config_file),
         {:ok, decoded} <- Jason.decode(data) do
      {decoded["username"], decoded["password"]}
    else
      _ ->
        username = IO.gets("username (including nusstu\\ prefix): ") |> String.trim()
        password = password_get("password: ") |> String.trim()
        {username, password}
    end
  end

  @spec clear_credentials() :: :ok | nil
  defp clear_credentials do
    case Elixir.File.rm(@config_file) do
      :ok ->
        IO.puts("Cleared stored credentials")
        :ok

      {:error, _} ->
        nil
    end
  end

  @spec save_credentials(String.t(), String.t()) :: :ok | :error
  defp save_credentials(username, password) when is_binary(username) and is_binary(password) do
    data = %{username: username, password: password}

    with {:write?, true} <-
           {:write?,
            not Elixir.File.exists?(@config_file) and
              confirm?(
                "Do you want to store your credential? (WARNING: they are stored in plain text) [y/n]"
              )},
         {:ok, encoded} <- Jason.encode(data),
         :ok <- Elixir.File.write(@config_file, encoded) do
      :ok
    else
      {:write?, false} ->
        :ok

      {:error, reason} ->
        IO.puts("Unable to save credentials: #{reason}")
        :error
    end
  end

  @spec confirm?(String.t()) :: bool()
  defp confirm?(prompt) when is_binary(prompt) do
    answer = prompt |> IO.gets() |> String.trim() |> String.downcase()

    case answer do
      "y" -> true
      "n" -> false
      _ -> confirm?(prompt)
    end
  end

  @spec list_file(File.t(), Authorization.t()) :: :ok
  defp list_file(file, auth), do: list_file(file, auth, "")

  defp list_file(file, auth, prefix) when is_binary(prefix) do
    if file.directory? do
      file.children
      |> Enum.map(fn child ->
        GenRetry.Task.async(fn ->
          {:ok, child} = File.load_children(child, auth)
          child
        end)
      end)
      |> Enum.each(fn task ->
        child = Task.await(task, :infinity)
        list_file(child, auth, "#{prefix}/#{file.name}")
      end)
    else
      IO.puts("#{prefix}/#{file.name}")
    end
  end

  # From Mix.Hex.Utils
  # Password prompt that hides input by every 1ms
  # clearing the line with stderr
  @spec password_get(String.t()) :: String.t()
  defp password_get(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets(prompt)

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    value
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt}")
        loop(prompt)
    end
  end
end
