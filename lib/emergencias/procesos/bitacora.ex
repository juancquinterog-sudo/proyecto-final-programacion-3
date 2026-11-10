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

  @doc "Devuelve los eventos de un usuario."
  @spec consultar(String.t()) :: [map()]
  def consultar(_usuario), do: []

  # TODO: implementar receive para cada mensaje y volver a llamar loop/1 (recursión de cola)
  defp loop(eventos) do
    receive do
      :detener -> :ok
      _otro -> loop(eventos)
    end
  end
end
