defmodule Emergencias.Servidores.AlbergueServer do
  @moduledoc """
  UN proceso por albergue (req. 1.4.8). Serializa ingresos y salidas, de modo
  que dos personas que llegan a la vez al último cupo no superen la capacidad.

  Registro: `{:via, Registry, {Emergencias.Registry, {:albergue, codigo}}}`.
  Supervisado por `Emergencias.AlbergueDinamico` (DynamicSupervisor).
  """
  use GenServer, restart: :transient

  alias Emergencias.Dominio.Albergue

  @spec registrar(Albergue.t()) :: {:ok, pid()} | {:error, atom()}
  def registrar(%Albergue{} = _albergue), do: {:error, :no_implementado}

  def start_link(%Albergue{} = albergue) do
    GenServer.start_link(__MODULE__, albergue, name: via(albergue.codigo))
  end

  def via(codigo), do: {:via, Registry, {Emergencias.Registry, {:albergue, codigo}}}

  @spec consultar(String.t()) :: {:ok, Albergue.t()} | {:error, :no_existe}
  def consultar(_codigo), do: {:error, :no_implementado}

  @spec registrar_entrada(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_entrada(_codigo, _documento), do: {:error, :no_implementado}

  @spec registrar_salida(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_salida(_codigo, _documento), do: {:error, :no_implementado}

  @spec listar() :: [Albergue.t()]
  def listar, do: []

  @impl true
  def init(%Albergue{} = albergue), do: {:ok, albergue}
end
