defmodule Emergencias.Servidores.PersonaServer do
  @moduledoc """
  Personas afectadas y mensajes entre familiares (req. 1.4.6).

  Estado: `%{personas: %{documento => Persona}, mensajes: %{documento => [Mensaje]}}`.
  """
  use GenServer

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec reportar(map()) :: {:ok, map()} | {:error, atom()}
  def reportar(_datos), do: {:error, :no_implementado}

  @spec buscar(keyword()) :: [map()]
  def buscar(_filtros), do: []

  @spec cambiar_estado(String.t(), atom(), String.t()) :: {:ok, map()} | {:error, atom()}
  def cambiar_estado(_documento, _estado, _usuario), do: {:error, :no_implementado}

  @spec enviar_mensaje(map()) :: {:ok, map()} | {:error, atom()}
  def enviar_mensaje(_datos), do: {:error, :no_implementado}

  @spec listar_mensajes(String.t()) :: [map()]
  def listar_mensajes(_documento), do: []

  @spec marcar_mensaje(String.t(), :entregado | :pendiente) :: {:ok, map()} | {:error, atom()}
  def marcar_mensaje(_id, _estado), do: {:error, :no_implementado}

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    # TODO: cargar el estado desde el archivo de texto plano (Persistencia.Almacen)
    # para recuperarse tras un reinicio del supervisor.
    {:ok, %{}}
  end
end
