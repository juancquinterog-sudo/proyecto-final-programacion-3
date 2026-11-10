defmodule Emergencias.Servidores.MascotaServer do
  @moduledoc """
  Reportes de mascotas perdidas y encontradas (req. 1.4.7).

  Estado: `%{reportes: %{id => Mascota}}`. `confirmar_coincidencia/2` cierra ambos
  reportes en UNA sola llamada: evita que un reporte se resuelva dos veces.
  """
  use GenServer

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec reportar(map()) :: {:ok, map()} | {:error, atom()}
  def reportar(_datos), do: {:error, :no_implementado}

  @spec listar(keyword()) :: [map()]
  def listar(_filtros \\ []), do: []

  @spec buscar_coincidencias() :: [{map(), map(), float()}]
  def buscar_coincidencias, do: []

  @spec confirmar_coincidencia(String.t(), String.t()) :: {:ok, term()} | {:error, atom()}
  def confirmar_coincidencia(_id_perdida, _id_encontrada), do: {:error, :no_implementado}

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    # TODO: cargar el estado desde el archivo de texto plano (Persistencia.Almacen)
    # para recuperarse tras un reinicio del supervisor.
    {:ok, %{}}
  end
end
