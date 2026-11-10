defmodule Emergencias.Servidores.ZonaServer do
  @moduledoc """
  Zonas, sectores y puntos de atención (req. 1.4.3).

  Estado: `%{codigo_zona => Zona}`. Usa las funciones recursivas de `Dominio.Zona`
  para el estado general y las estadísticas acumuladas.
  """
  use GenServer

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec registrar(map()) :: {:ok, map()} | {:error, atom()}
  def registrar(_datos), do: {:error, :no_implementado}

  @spec agregar_sector(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def agregar_sector(_zona, _datos), do: {:error, :no_implementado}

  @spec consultar(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def consultar(_codigo), do: {:error, :no_implementado}

  @spec estadisticas(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def estadisticas(_codigo), do: {:error, :no_implementado}

  @spec listar() :: [map()]
  def listar, do: []

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    # TODO: cargar el estado desde el archivo de texto plano (Persistencia.Almacen)
    # para recuperarse tras un reinicio del supervisor.
    {:ok, %{}}
  end
end
