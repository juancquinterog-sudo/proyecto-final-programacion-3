defmodule Emergencias.Servidores.MascotaServer do
  @moduledoc """
  Reportes de mascotas perdidas y encontradas (req. 1.4.7).

  Estado: `%{reportes: %{id => Mascota}, siguiente: n}`. `confirmar_coincidencia/2`
  cierra ambos reportes en UNA sola llamada: un reporte nunca se resuelve dos veces.
  Persistencia en `mascotas.txt` (se recarga en `init/1`).
  """
  use GenServer

  require Logger

  alias Emergencias.Dominio.{Mascota, Similitud, Validaciones}
  alias Emergencias.Persistencia.Almacen

  @tamanos %{
    "pequena" => :pequena,
    "pequeña" => :pequena,
    "mediana" => :mediana,
    "grande" => :grande
  }

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Registra un reporte. `datos`: `:tipo` (lost/found), `:especie`, `:zona` y opcionales `:nombre`, `:color`, `:tamano`, `:contacto`, `:caracteristicas`."
  @spec reportar(map()) :: {:ok, Mascota.t()} | {:error, atom()}
  def reportar(datos), do: GenServer.call(__MODULE__, {:reportar, datos})

  @doc "Filtra por `:especie`, `:zona`, `:estado`, `:tipo`."
  @spec listar(keyword()) :: [Mascota.t()]
  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "Calcula coincidencias (>= umbral) y marca los reportes implicados como `:posible_coincidencia`."
  @spec buscar_coincidencias() :: [{Mascota.t(), Mascota.t(), float()}]
  def buscar_coincidencias, do: GenServer.call(__MODULE__, :buscar_coincidencias)

  @spec confirmar_coincidencia(String.t(), String.t()) ::
          {:ok, {Mascota.t(), Mascota.t()}} | {:error, atom()}
  def confirmar_coincidencia(id_perdida, id_encontrada),
    do: GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada})

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    lista =
      case Almacen.cargar(:mascotas) do
        {:ok, lista} ->
          lista

        {:error, razon} ->
          Logger.warning("No se pudo cargar mascotas.txt: #{inspect(razon)}")
          []
      end

    reportes = Map.new(lista, &{&1.id, &1})
    {:ok, %{reportes: reportes, siguiente: siguiente(Map.keys(reportes))}}
  end

  @impl true
  def handle_call({:reportar, datos}, _from, estado) do
    id = "M" <> String.pad_leading(Integer.to_string(estado.siguiente), 3, "0")

    with {:ok, tipo} <- Validaciones.tipo_reporte(datos[:tipo]),
         {:ok, especie} <- Validaciones.texto_no_vacio(datos[:especie]),
         {:ok, zona} <- Validaciones.texto_no_vacio(datos[:zona]),
         {:ok, tamano} <- tamano(datos[:tamano]),
         {:ok, mascota} <-
           Mascota.nuevo(%{
             id: id,
             tipo: tipo,
             especie: String.downcase(especie),
             nombre: nombre(datos[:nombre]),
             color: texto_o_nil(datos[:color]),
             tamano: tamano,
             zona: zona,
             contacto: texto_o_nil(datos[:contacto]),
             caracteristicas: caracteristicas(datos[:caracteristicas])
           }),
         reportes = Map.put(estado.reportes, id, mascota),
         :ok <- guardar(reportes) do
      {:reply, {:ok, mascota}, %{estado | reportes: reportes, siguiente: estado.siguiente + 1}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista =
      estado.reportes
      |> ordenados()
      |> Enum.filter(fn m ->
        Enum.all?(filtros, fn
          {:especie, v} -> String.downcase(to_string(m.especie)) == String.downcase(to_string(v))
          {:zona, v} -> m.zona == v
          {:estado, v} -> m.estado == v
          {:tipo, v} -> m.tipo == v
          _ -> true
        end)
      end)

    {:reply, lista, estado}
  end

  def handle_call(:buscar_coincidencias, _from, estado) do
    coincidencias = estado.reportes |> ordenados() |> Similitud.buscar_coincidencias()

    ids = coincidencias |> Enum.flat_map(fn {p, e, _} -> [p.id, e.id] end) |> Enum.uniq()

    reportes =
      Enum.reduce(ids, estado.reportes, fn id, acum ->
        case Mascota.cambiar_estado(acum[id], :posible_coincidencia) do
          {:ok, marcada} -> Map.put(acum, id, marcada)
          {:error, _} -> acum
        end
      end)

    _ = guardar(reportes)

    resultado =
      Enum.map(coincidencias, fn {p, e, puntos} -> {reportes[p.id], reportes[e.id], puntos} end)

    {:reply, resultado, %{estado | reportes: reportes}}
  end

  def handle_call({:confirmar, id_perdida, id_encontrada}, _from, estado) do
    with {:ok, perdida} <- buscar(estado, id_perdida),
         {:ok, encontrada} <- buscar(estado, id_encontrada),
         {:ok, {p, e}} <- Mascota.confirmar_coincidencia(perdida, encontrada),
         reportes = estado.reportes |> Map.put(p.id, p) |> Map.put(e.id, e),
         :ok <- guardar(reportes) do
      {:reply, {:ok, {p, e}}, %{estado | reportes: reportes}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  ## Privadas

  defp buscar(estado, id) do
    case Map.fetch(estado.reportes, id) do
      {:ok, m} -> {:ok, m}
      :error -> {:error, :no_existe}
    end
  end

  defp guardar(reportes), do: Almacen.guardar(:mascotas, ordenados(reportes))

  defp ordenados(reportes),
    do: reportes |> Map.values() |> Enum.sort_by(&{String.length(&1.id), &1.id})

  defp tamano(nil), do: {:ok, nil}

  defp tamano(valor) do
    case Map.fetch(@tamanos, valor |> to_string() |> String.downcase()) do
      {:ok, t} -> {:ok, t}
      :error -> {:error, :tamano_invalido}
    end
  end

  defp nombre(valor) do
    case texto_o_nil(valor) do
      nil -> nil
      n -> if String.downcase(n) in ["desconocido", "-"], do: nil, else: n
    end
  end

  defp texto_o_nil(valor) when is_binary(valor) do
    case String.trim(valor) do
      "" -> nil
      t -> t
    end
  end

  defp texto_o_nil(_), do: nil

  defp caracteristicas(nil), do: MapSet.new()
  defp caracteristicas(%MapSet{} = set), do: set

  defp caracteristicas(texto) when is_binary(texto) do
    texto
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> MapSet.new()
  end

  defp siguiente(ids) do
    nums =
      Enum.map(ids, fn "M" <> n ->
        case Integer.parse(n) do
          {v, ""} -> v
          _ -> 0
        end
      end)

    Enum.max([0 | nums]) + 1
  end
end
