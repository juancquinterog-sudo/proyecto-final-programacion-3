defmodule Emergencias.Servidores.NecesidadServer do
  @moduledoc """
  Necesidades puntuales (req. 1.4.4).

  Estado: `%{necesidades: %{id => Necesidad}, siguiente_id: n}`.

  Concurrencia: al ser UN proceso, las transiciones de estado se serializan.
  `reservar_para_asignar/1` hace un compare-and-set (solo pasa si la necesidad
  está `:pendiente` o `:asignada` con faltante > 0), de modo que una necesidad
  atendida/cancelada NUNCA vuelve a consumir recursos ni se cierra dos veces.
  """
  use GenServer

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec registrar(map()) :: {:ok, map()} | {:error, atom()}
  def registrar(_datos), do: {:error, :no_implementado}

  @spec listar(keyword()) :: [map()]
  def listar(_filtros \\ []), do: []

  @spec obtener(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def obtener(_id), do: {:error, :no_implementado}

  @spec registrar_asignacion(String.t(), {String.t(), String.t(), pos_integer()}) ::
          {:ok, map()} | {:error, atom()}
  def registrar_asignacion(_id, _asignacion), do: {:error, :no_implementado}

  @spec cambiar_estado(String.t(), atom()) :: {:ok, map()} | {:error, atom()}
  def cambiar_estado(_id, _nuevo), do: {:error, :no_implementado}

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    # TODO: cargar el estado desde el archivo de texto plano (Persistencia.Almacen)
    # para recuperarse tras un reinicio del supervisor.
    {:ok, %{}}
  end
end
