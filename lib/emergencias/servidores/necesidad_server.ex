defmodule Emergencias.Servidores.NecesidadServer do
  @moduledoc """
  Necesidades puntuales (req. 1.4.4).

  Estado: `%{necesidades: %{id => Necesidad}, siguiente: n}`. Los identificadores
  son únicos y secuenciales (`N001`, `N002`, ...).

  Concurrencia: al ser UN proceso, las operaciones sobre una necesidad se
  serializan. `registrar_asignacion/2` y `cambiar_estado/2` validan DENTRO del
  servidor, por lo que una necesidad atendida/cancelada NUNCA vuelve a consumir
  recursos ni se cierra dos veces, aunque lleguen solicitudes simultáneas.

  La prioridad se usa de verdad: `listar/1` y `pendientes/0` devuelven las
  necesidades ordenadas (crítica primero; a igual prioridad, por llegada).

  Persistencia: cada cambio reescribe `necesidades.txt` antes de actualizar el
  estado; `init/1` lo recarga (y continúa la numeración de ids).
  """
  use GenServer

  require Logger

  alias Emergencias.Dominio.Necesidad
  alias Emergencias.Persistencia.Almacen

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc """
  Registra una necesidad. `datos`: `:tipo`, `:cantidad`, `:prioridad`, `:zona`
  (obligatorios) y `:descripcion`, `:reportado_por`. El id y la fecha los pone el servidor.
  """
  @spec registrar(map()) :: {:ok, Necesidad.t()} | {:error, term()}
  def registrar(datos), do: GenServer.call(__MODULE__, {:registrar, datos})

  @doc "Lista filtrada (`:zona`, `:tipo`, `:prioridad`, `:estado`) y ordenada por prioridad."
  @spec listar(keyword()) :: [Necesidad.t()]
  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "Necesidades que aún requieren atención, la más urgente primero."
  @spec pendientes() :: [Necesidad.t()]
  def pendientes, do: GenServer.call(__MODULE__, :pendientes)

  @spec obtener(String.t()) :: {:ok, Necesidad.t()} | {:error, :no_existe}
  def obtener(id), do: GenServer.call(__MODULE__, {:obtener, id})

  @spec registrar_asignacion(String.t(), {String.t(), String.t(), pos_integer()}) ::
          {:ok, Necesidad.t()} | {:error, term()}
  def registrar_asignacion(id, asignacion),
    do: GenServer.call(__MODULE__, {:registrar_asignacion, id, asignacion})

  @spec cambiar_estado(String.t(), atom()) :: {:ok, Necesidad.t()} | {:error, term()}
  def cambiar_estado(id, nuevo), do: GenServer.call(__MODULE__, {:cambiar_estado, id, nuevo})

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    necesidades =
      case Almacen.cargar(:necesidades) do
        {:ok, lista} ->
          Map.new(lista, fn necesidad -> {necesidad.id, necesidad} end)

        {:error, razon} ->
          Logger.warning("No se pudo cargar necesidades.txt: #{inspect(razon)}")
          %{}
      end

    {:ok, %{necesidades: necesidades, siguiente: siguiente_numero(Map.keys(necesidades))}}
  end

  @impl true
  def handle_call({:registrar, datos}, _from, estado) do
    id = formato_id(estado.siguiente)
    ahora = DateTime.utc_now() |> DateTime.truncate(:second)
    datos = datos |> Map.put(:id, id) |> Map.put(:creada_en, ahora)

    with {:ok, necesidad} <- Necesidad.nueva(datos),
         {:ok, mapa} <- persistir(Map.put(estado.necesidades, id, necesidad)) do
      {:reply, {:ok, necesidad}, %{estado | necesidades: mapa, siguiente: estado.siguiente + 1}}
    else
      {:error, _razon} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista = estado |> todas() |> Necesidad.filtrar(filtros) |> Necesidad.ordenar()
    {:reply, lista, estado}
  end

  def handle_call(:pendientes, _from, estado) do
    lista = estado |> todas() |> Enum.filter(&Necesidad.pendiente?/1) |> Necesidad.ordenar()
    {:reply, lista, estado}
  end

  def handle_call({:obtener, id}, _from, estado) do
    respuesta =
      case Map.fetch(estado.necesidades, id) do
        {:ok, necesidad} -> {:ok, necesidad}
        :error -> {:error, :no_existe}
      end

    {:reply, respuesta, estado}
  end

  def handle_call({:registrar_asignacion, id, asignacion}, _from, estado) do
    {respuesta, nuevo} =
      actualizar(estado, id, fn necesidad -> Necesidad.registrar_asignacion(necesidad, asignacion) end)

    {:reply, respuesta, nuevo}
  end

  def handle_call({:cambiar_estado, id, nuevo_estado}, _from, estado) do
    {respuesta, nuevo} =
      actualizar(estado, id, fn necesidad -> Necesidad.cambiar_estado(necesidad, nuevo_estado) end)

    {:reply, respuesta, nuevo}
  end

  ## Privadas

  # Aplica `fun` a una necesidad; si todo sale bien persiste y actualiza el estado.
  defp actualizar(estado, id, fun) do
    with {:ok, necesidad} <- buscar(estado, id),
         {:ok, nueva} <- fun.(necesidad),
         {:ok, mapa} <- persistir(Map.put(estado.necesidades, id, nueva)) do
      {{:ok, nueva}, %{estado | necesidades: mapa}}
    else
      {:error, _razon} = error -> {error, estado}
    end
  end

  defp buscar(estado, id) do
    case Map.fetch(estado.necesidades, id) do
      {:ok, necesidad} -> {:ok, necesidad}
      :error -> {:error, :no_existe}
    end
  end

  # En orden de llegada (N999 < N1000: primero por longitud, luego por texto).
  defp todas(%{necesidades: mapa}), do: ordenar_por_llegada(mapa)

  defp ordenar_por_llegada(mapa) do
    mapa |> Map.values() |> Enum.sort_by(fn n -> {String.length(n.id), n.id} end)
  end

  defp persistir(mapa) do
    case Almacen.guardar(:necesidades, ordenar_por_llegada(mapa)) do
      :ok -> {:ok, mapa}
      {:error, razon} -> {:error, {:persistencia, razon}}
    end
  end

  defp formato_id(numero), do: "N" <> String.pad_leading(Integer.to_string(numero), 3, "0")

  defp siguiente_numero(ids), do: Enum.max([0 | Enum.map(ids, &numero/1)]) + 1

  defp numero("N" <> resto) do
    case Integer.parse(resto) do
      {n, ""} -> n
      _ -> 0
    end
  end

  defp numero(_otro), do: 0
end
