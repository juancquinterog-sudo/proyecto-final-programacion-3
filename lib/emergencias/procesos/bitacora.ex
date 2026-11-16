defmodule Emergencias.Procesos.Bitacora do
  @moduledoc """
  PROCESO INDEPENDIENTE (sin GenServer): `spawn_link` + `receive` + recursión.
  Registra la actividad de cada usuario (req. 1.4.1) y la anexa a `actividad.log`.

  Protocolo de mensajes:

      {:actividad, usuario, comando, resultado}   # cast, no espera respuesta
      {:consultar, usuario, pid_cliente}          # responde {:actividad, [..]} al cliente
      :detener

  El `loop/1` es recursivo por cola: el estado (lista de eventos) viaja como
  argumento, no se usa ninguna variable mutable.
  """

  alias Emergencias.Persistencia.Escritor

  @nombre __MODULE__

  def child_spec(_arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :permanent}
  end

  def start_link do
    pid = spawn_link(fn -> loop([]) end)
    Process.register(pid, @nombre)
    {:ok, pid}
  end

  @doc "Registra una acción (asíncrono)."
  @spec registrar(String.t(), atom(), term()) :: :ok
  def registrar(usuario, comando, resultado) do
    send(@nombre, {:actividad, usuario, comando, resultado})
    :ok
  end

  @doc "Devuelve los eventos de un usuario (el más reciente primero)."
  @spec consultar(String.t()) :: [map()]
  def consultar(usuario) do
    send(@nombre, {:consultar, usuario, self()})

    receive do
      {:actividad, eventos} -> eventos
    after
      1_000 -> []
    end
  end

  defp loop(eventos) do
    receive do
      {:actividad, usuario, comando, resultado} ->
        evento = %{
          usuario: usuario,
          comando: comando,
          resultado: resultado,
          fecha: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        guardar(evento)
        loop([evento | eventos])

      {:consultar, usuario, cliente} ->
        send(cliente, {:actividad, Enum.filter(eventos, fn e -> e.usuario == usuario end)})
        loop(eventos)

      :detener ->
        :ok

      _otro ->
        loop(eventos)
    end
  end

  defp guardar(e) do
    ruta = Path.join(Application.get_env(:emergencias, :data_dir, "data"), "actividad.log")
    resultado = e.resultado |> inspect() |> String.replace(~r/[|\r\n]/, " ")
    linea = Enum.join([DateTime.to_iso8601(e.fecha), e.usuario, e.comando, resultado], "|")
    Escritor.anexar(ruta, linea)
  end
end
