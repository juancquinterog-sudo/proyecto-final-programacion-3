defmodule Emergencias.Servidores.ZonaServer do
  @moduledoc """
  Zonas, sectores y puntos de atención (req. 1.4.3).

  Estado: `%{codigo_zona => Zona}`. Usa las funciones recursivas de `Dominio.Zona`
  para las estadísticas acumuladas.

  Persistencia: cada cambio reescribe `zonas.txt` ANTES de actualizar el estado
  (si falla el disco, el estado en memoria no cambia). En `init/1` se recarga el
  archivo, así las zonas sobreviven a un reinicio del proceso.
  """
  use GenServer

  require Logger

  alias Emergencias.Dominio.{PuntoAtencion, Sector, Validaciones, Zona}
  alias Emergencias.Persistencia.Almacen

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Registra una zona. `datos`: `:codigo`, `:nombre`, `:nivel`, `:personas_estimadas` (opcional)."
  @spec registrar(map()) :: {:ok, Zona.t()} | {:error, term()}
  def registrar(datos), do: GenServer.call(__MODULE__, {:registrar, datos})

  @spec agregar_sector(String.t(), map()) :: {:ok, Zona.t()} | {:error, term()}
  def agregar_sector(codigo_zona, datos),
    do: GenServer.call(__MODULE__, {:agregar_sector, codigo_zona, datos})

  @spec agregar_punto(String.t(), String.t(), map()) :: {:ok, Zona.t()} | {:error, term()}
  def agregar_punto(codigo_zona, codigo_sector, datos),
    do: GenServer.call(__MODULE__, {:agregar_punto, codigo_zona, codigo_sector, datos})

  @spec consultar(String.t()) :: {:ok, Zona.t()} | {:error, :no_existe}
  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})

  @spec estadisticas(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def estadisticas(codigo), do: GenServer.call(__MODULE__, {:estadisticas, codigo})

  @doc "Todas las zonas ordenadas por código."
  @spec listar() :: [Zona.t()]
  def listar, do: GenServer.call(__MODULE__, :listar)

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    zonas =
      case Almacen.cargar(:zonas) do
        {:ok, lista} ->
          Map.new(lista, fn zona -> {zona.codigo, zona} end)

        {:error, razon} ->
          Logger.warning("No se pudo cargar zonas.txt: #{inspect(razon)}")
          %{}
      end

    {:ok, zonas}
  end

  @impl true
  def handle_call({:registrar, datos}, _from, zonas) do
    with {:ok, zona} <- Zona.nueva(datos),
         :ok <- Validaciones.id_libre?(zona.codigo, Map.keys(zonas)),
         {:ok, nuevas} <- persistir(Map.put(zonas, zona.codigo, zona)) do
      {:reply, {:ok, zona}, nuevas}
    else
      {:error, _razon} = error -> {:reply, error, zonas}
    end
  end

  def handle_call({:agregar_sector, codigo_zona, datos}, _from, zonas) do
    {respuesta, nuevas} =
      modificar(zonas, codigo_zona, fn zona ->
        with {:ok, sector} <- Sector.nuevo(datos), do: Zona.agregar_sector(zona, sector)
      end)

    {:reply, respuesta, nuevas}
  end

  def handle_call({:agregar_punto, codigo_zona, codigo_sector, datos}, _from, zonas) do
    {respuesta, nuevas} =
      modificar(zonas, codigo_zona, fn zona ->
        with {:ok, punto} <- PuntoAtencion.nuevo(datos),
             do: Zona.agregar_punto(zona, codigo_sector, punto)
      end)

    {:reply, respuesta, nuevas}
  end

  def handle_call({:consultar, codigo}, _from, zonas), do: {:reply, buscar(zonas, codigo), zonas}

  def handle_call({:estadisticas, codigo}, _from, zonas) do
    respuesta =
      with {:ok, zona} <- buscar(zonas, codigo), do: {:ok, Zona.estadisticas(zona)}

    {:reply, respuesta, zonas}
  end

  def handle_call(:listar, _from, zonas), do: {:reply, ordenadas(zonas), zonas}

  ## Privadas

  defp buscar(zonas, codigo) do
    case Map.fetch(zonas, codigo) do
      {:ok, zona} -> {:ok, zona}
      :error -> {:error, :no_existe}
    end
  end

  # Aplica `fun` a una zona; si todo sale bien persiste y actualiza el estado.
  defp modificar(zonas, codigo, fun) do
    with {:ok, zona} <- buscar(zonas, codigo),
         {:ok, nueva} <- fun.(zona),
         {:ok, nuevas} <- persistir(Map.put(zonas, codigo, nueva)) do
      {{:ok, nueva}, nuevas}
    else
      {:error, _razon} = error -> {error, zonas}
    end
  end

  defp ordenadas(zonas), do: zonas |> Map.values() |> Enum.sort_by(fn zona -> zona.codigo end)

  defp persistir(zonas) do
    case Almacen.guardar(:zonas, ordenadas(zonas)) do
      :ok -> {:ok, zonas}
      {:error, razon} -> {:error, {:persistencia, razon}}
    end
  end
end
