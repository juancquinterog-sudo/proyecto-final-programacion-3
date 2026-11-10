defmodule Emergencias.Persistencia.Restaurador do
  @moduledoc """
  Tarea transitoria (`restart: :transient`) que, al arrancar el subárbol de
  recursos o albergues, lee el archivo y crea un proceso por cada registro
  (`RecursoServer.registrar/1` o `AlbergueServer.registrar/1`).
  """
  use Task, restart: :transient

  def start_link(entidad), do: Task.start_link(__MODULE__, :ejecutar, [entidad])

  @spec ejecutar(:recursos | :albergues) :: :ok
  def ejecutar(_entidad) do
    # TODO: Almacen.cargar(entidad) |> Enum.each(&registrar/1)
    :ok
  end
end
