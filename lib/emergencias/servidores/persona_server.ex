defmodule Emergencias.Servidores.PersonaServer do
  @moduledoc """
  Personas afectadas y mensajes entre familiares (req. 1.4.6).

  Estado: `%{personas: %{documento => Persona}, mensajes: %{id => Mensaje}, siguiente: n}`.
  Un solo proceso serializa las operaciones: el mismo documento no se registra dos
  veces y los cambios de estado respetan el grafo de transiciones (`Dominio.Estados`).
  Cada cambio se guarda en `personas.txt` / `mensajes.txt`; `init/1` los recarga.
  """
  use GenServer

  require Logger

  alias Emergencias.Dominio.{Mensaje, Persona, Validaciones}
  alias Emergencias.Persistencia.Almacen

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Registra una persona. `datos`: `:documento`, `:nombre`, `:zona` y opcionales `:estado`, `:edad`, `:usuario`."
  @spec reportar(map()) :: {:ok, Persona.t()} | {:error, atom()}
  def reportar(datos), do: GenServer.call(__MODULE__, {:reportar, datos})

  @doc "Busca por `:nombre`, `:documento`, `:zona` o `:estado` (keyword)."
  @spec buscar(keyword()) :: [Persona.t()]
  def buscar(filtros), do: GenServer.call(__MODULE__, {:buscar, filtros})

  @spec cambiar_estado(String.t(), atom(), String.t()) :: {:ok, Persona.t()} | {:error, atom()}
  def cambiar_estado(documento, estado, usuario),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, estado, usuario})

  @doc "Envía un mensaje. `datos`: `:destinatario` (documento), `:remitente`, `:contenido`."
  @spec enviar_mensaje(map()) :: {:ok, Mensaje.t()} | {:error, atom()}
  def enviar_mensaje(datos), do: GenServer.call(__MODULE__, {:enviar_mensaje, datos})

  @spec listar_mensajes(String.t()) :: [Mensaje.t()]
  def listar_mensajes(documento), do: GenServer.call(__MODULE__, {:listar_mensajes, documento})

  @spec marcar_mensaje(String.t(), :entregado | :pendiente) ::
          {:ok, Mensaje.t()} | {:error, atom()}
  def marcar_mensaje(id, estado), do: GenServer.call(__MODULE__, {:marcar_mensaje, id, estado})

  @doc "Todas las personas y mensajes (para el resumen global)."
  @spec todo() :: %{personas: [Persona.t()], mensajes: [Mensaje.t()]}
  def todo, do: GenServer.call(__MODULE__, :todo)

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    personas = cargar(:personas)
    mensajes = cargar(:mensajes)

    {:ok,
     %{
       personas: Map.new(personas, &{&1.documento, &1}),
       mensajes: Map.new(mensajes, &{&1.id, &1}),
       siguiente: siguiente(mensajes)
     }}
  end

  @impl true
  def handle_call({:reportar, datos}, _from, estado) do
    with {:ok, documento} <- Validaciones.texto_no_vacio(datos[:documento]),
         {:ok, nombre} <- Validaciones.texto_no_vacio(datos[:nombre]),
         {:ok, zona} <- Validaciones.texto_no_vacio(datos[:zona]),
         {:ok, estado_p} <- estado_inicial(datos[:estado]),
         {:ok, edad} <- Validaciones.entero_no_negativo_o(datos[:edad], nil),
         :ok <- Validaciones.id_libre?(documento, Map.keys(estado.personas)),
         {:ok, persona} <-
           Persona.nueva(%{
             documento: documento,
             nombre: nombre,
             zona: zona,
             estado: estado_p,
             edad: edad,
             usuario: datos[:usuario] || "sistema"
           }),
         personas = Map.put(estado.personas, documento, persona),
         :ok <- Almacen.guardar(:personas, Map.values(personas)) do
      {:reply, {:ok, persona}, %{estado | personas: personas}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:buscar, filtros}, _from, estado) do
    {:reply,
     estado.personas |> Map.values() |> Persona.buscar(filtros) |> Enum.sort_by(& &1.documento),
     estado}
  end

  def handle_call({:cambiar_estado, documento, nuevo, usuario}, _from, estado) do
    with {:ok, persona} <- Map.fetch(estado.personas, documento) |> a_resultado(),
         {:ok, nueva} <- Persona.cambiar_estado(persona, nuevo, usuario),
         personas = Map.put(estado.personas, documento, nueva),
         :ok <- Almacen.guardar(:personas, Map.values(personas)) do
      {:reply, {:ok, nueva}, %{estado | personas: personas}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:enviar_mensaje, datos}, _from, estado) do
    with {:ok, destinatario} <- Validaciones.texto_no_vacio(datos[:destinatario]),
         {:ok, remitente} <- Validaciones.texto_no_vacio(datos[:remitente]),
         {:ok, contenido} <- Validaciones.texto_no_vacio(datos[:contenido]),
         true <- Map.has_key?(estado.personas, destinatario) or {:error, :no_existe},
         {:ok, mensaje} <-
           Mensaje.nuevo(%{
             id: "MSG" <> String.pad_leading(Integer.to_string(estado.siguiente), 3, "0"),
             destinatario: destinatario,
             remitente: remitente,
             contenido: contenido
           }),
         mensajes = Map.put(estado.mensajes, mensaje.id, mensaje),
         :ok <- Almacen.guardar(:mensajes, ordenar(mensajes)) do
      {:reply, {:ok, mensaje}, %{estado | mensajes: mensajes, siguiente: estado.siguiente + 1}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:listar_mensajes, documento}, _from, estado) do
    lista = estado.mensajes |> ordenar() |> Enum.filter(&(&1.destinatario == documento))
    {:reply, lista, estado}
  end

  def handle_call({:marcar_mensaje, id, nuevo}, _from, estado) do
    with {:ok, mensaje} <- Map.fetch(estado.mensajes, id) |> a_resultado(),
         {:ok, marcado} <- Mensaje.marcar(mensaje, nuevo),
         mensajes = Map.put(estado.mensajes, id, marcado),
         :ok <- Almacen.guardar(:mensajes, ordenar(mensajes)) do
      {:reply, {:ok, marcado}, %{estado | mensajes: mensajes}}
    else
      {:error, _} = error -> {:reply, error, estado}
    end
  end

  def handle_call(:todo, _from, estado) do
    {:reply, %{personas: Map.values(estado.personas), mensajes: ordenar(estado.mensajes)}, estado}
  end

  ## Privadas

  defp estado_inicial(nil), do: {:ok, :reportada}
  defp estado_inicial(valor), do: Validaciones.estado(:persona, valor)

  defp a_resultado({:ok, _} = ok), do: ok
  defp a_resultado(:error), do: {:error, :no_existe}

  defp ordenar(mensajes),
    do: mensajes |> Map.values() |> Enum.sort_by(&{String.length(&1.id), &1.id})

  defp siguiente(mensajes) do
    numeros =
      Enum.map(mensajes, fn %{id: "MSG" <> n} ->
        case Integer.parse(n) do
          {v, ""} -> v
          _ -> 0
        end
      end)

    Enum.max([0 | numeros]) + 1
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
