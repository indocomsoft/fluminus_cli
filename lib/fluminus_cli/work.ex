defmodule FluminusCLI.Work do
  @moduledoc """
  Declare this module as a behaviour to automatically register your work.
  """

  @doc "The option to trigger this work"
  @callback option :: atom()
  @callback short_doc :: String.t()
  @callback process_module(
              module :: Fluminus.API.Module.t(),
              auth :: Fluminus.Authorization.t(),
              path :: String.t(),
              verbose :: boolean()
            ) :: any()

  @spec all_work :: [module()]
  def all_work do
    :code.all_available()
    |> Enum.filter(fn {mod, _, _} ->
      with true <- mod |> List.to_string() |> String.contains?("FluminusCLI.Work"),
           mod <- List.to_existing_atom(mod),
           behaviours when is_list(behaviours) <- mod.module_info(:attributes)[:behaviour],
           true <- Enum.member?(behaviours, __MODULE__) do
        true
      else
        _ -> false
      end
    end)
    |> Enum.map(fn {a, _, _} -> List.to_existing_atom(a) end)
  end
end
