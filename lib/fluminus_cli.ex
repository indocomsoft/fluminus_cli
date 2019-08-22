defmodule FluminusCLI do
  @moduledoc """
  Provides functions related to Fluminus' CLI.
  """

  @config_file "config.json"

  alias Fluminus.API.File
  alias Fluminus.Authorization

  def run(args) do
    HTTPoison.start()
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

  @spec run([String.t()], Authorization.t()) :: :ok
  defp run(args, auth = %Authorization{}) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [announcements: :boolean, files: :boolean, download_to: :string]
      )

    {:ok, name} = Fluminus.API.name(auth)
    IO.puts("Hi #{name}")
    {:ok, modules} = Fluminus.API.modules(auth, true)
    IO.puts("You are taking:")
    modules |> Enum.filter(&(not &1.teaching?)) |> Enum.each(&IO.puts("- #{&1.code} #{&1.name}"))
    IO.puts("And teaching:")
    modules |> Enum.filter(& &1.teaching?) |> Enum.each(&IO.puts("- #{&1.code} #{&1.name}"))
    IO.puts("")

    Enum.each(parsed, fn
      {:announcements, true} -> list_announcements(auth, modules)
      {:files, true} -> list_files(auth, modules)
      {:download_to, path} -> download_to(auth, modules, path)
    end)
  end

  defp download_to(auth, modules, path) do
    IO.puts("Download to #{path}")

    if Elixir.File.exists?(path) do
      modules
      |> Enum.map(fn mod ->
        GenRetry.Task.async(
          fn ->
            {:ok, file} = File.from_module(mod, auth)
            tasks = download_file(file, auth, path)

            Enum.each(tasks, &Task.await(&1, :infinity))
          end,
          retries: 10,
          delay: 0
        )
      end)
      |> Enum.each(&Task.await(&1, :infinity))
    else
      IO.puts("Download destination does not exist!")
    end
  end

  defp download_file(file, auth, path, tasks \\ []) do
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
          retries: 10,
          delay: 0
        )
      end)
      |> Enum.reduce(tasks, fn task, acc ->
        child = Task.await(task, :infinity)
        download_file(child, auth, destination, acc)
      end)
    else
      task =
        GenRetry.Task.async(
          fn ->
            case File.download(file, auth, path) do
              :ok ->
                IO.puts("Downloaded to #{destination}")

              {:error, :exists} ->
                :ok

              {:error, reason} ->
                IO.puts("Unable to download to #{destination}, reason: #{reason}")
            end
          end,
          retries: 10,
          delay: 0
        )

      [task | tasks]
    end
  end

  defp list_files(auth, modules) do
    IO.puts("\n# Files:\n")

    modules
    |> Enum.map(fn mod ->
      task =
        GenRetry.Task.async(fn ->
          {:ok, file} = File.from_module(mod, auth)
          file
        end)

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
