defmodule Emergencias.Persistencia.Restaurador do
  @moduledoc """
  Tarea transitoria (`restart: :transient`) que, al arrancar el subárbol de
  recursos o albergues, lee el archivo y crea un proceso por cada registro
  (`RecursoServer.restaurar/1` o `AlbergueServer.restaurar/1`).
  Los movimientos de `movimientos.txt` se reinyectan en el historial del recurso.
  """
  use Task, restart: :transient

  require Logger

  alias Emergencias.Persistencia.Almacen
  alias Emergencias.Servidores.{AlbergueServer, RecursoServer}

  def start_link(entidad), do: Task.start_link(__MODULE__, :ejecutar, [entidad])

  @spec ejecutar(:recursos | :albergues) :: :ok
  def ejecutar(:recursos) do
    movimientos = cargar(:movimientos)

    for recurso <- cargar(:recursos) do
      historial =
        movimientos |> Enum.filter(&(&1.codigo_recurso == recurso.codigo)) |> Enum.reverse()

      RecursoServer.restaurar(%{recurso | historial: historial})
    end

    :ok
  end

  def ejecutar(:albergues) do
    for albergue <- cargar(:albergues), do: AlbergueServer.restaurar(albergue)
    :ok
  end

  defp cargar(entidad) do
    case Almacen.cargar(entidad) do
      {:ok, lista} ->
        lista

      {:error, razon} ->
        Logger.warning("No se pudo cargar #{entidad}.txt: #{inspect(razon)}")
        []
    end
  end
end
