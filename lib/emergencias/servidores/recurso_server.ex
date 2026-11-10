defmodule Emergencias.Servidores.RecursoServer do
  @moduledoc """
  UN proceso por recurso (req. 1.4.5). Es el corazón de la REGLA DE CONCURRENCIA
  OBLIGATORIA: todas las solicitudes sobre el mismo recurso llegan al buzón
  (mailbox) de este proceso y se atienden de una en una, así que
  `existencias` nunca queda negativa ni se sobre-asigna.

  Registro por nombre: `{:via, Registry, {Emergencias.Registry, {:recurso, codigo}}}`.
  Se crea con `DynamicSupervisor.start_child(Emergencias.RecursoDinamico, ...)`.

  Estado: un `Dominio.Recurso` (existencias por ubicación + historial).
  Cada cambio se persiste vía `Persistencia.Escritor`.
  """
  use GenServer, restart: :transient

  alias Emergencias.Dominio.Recurso

  ## API

  @doc "Crea el proceso del recurso bajo el DynamicSupervisor."
  @spec registrar(Recurso.t()) :: {:ok, pid()} | {:error, atom()}
  def registrar(%Recurso{} = _recurso), do: {:error, :no_implementado}

  def start_link(%Recurso{} = recurso) do
    GenServer.start_link(__MODULE__, recurso, name: via(recurso.codigo))
  end

  def via(codigo), do: {:via, Registry, {Emergencias.Registry, {:recurso, codigo}}}

  @spec entrada(String.t(), String.t(), pos_integer(), map()) :: {:ok, Recurso.t()} | {:error, atom()}
  def entrada(_codigo, _ubicacion, _cantidad, _meta \\ %{}), do: {:error, :no_implementado}

  @spec salida(String.t(), String.t(), pos_integer(), map()) :: {:ok, Recurso.t()} | {:error, atom()}
  def salida(_codigo, _ubicacion, _cantidad, _meta \\ %{}), do: {:error, :no_implementado}

  @doc "Descuenta para una necesidad. Todo-o-nada: `{:error, :stock_insuficiente}` si no alcanza."
  @spec reservar(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, Recurso.t()} | {:error, :stock_insuficiente | atom()}
  def reservar(_codigo, _ubicacion, _cantidad, _id_necesidad), do: {:error, :no_implementado}

  @doc "Devuelve lo reservado (rollback si falla el registro en la necesidad)."
  @spec liberar(String.t(), String.t(), pos_integer(), String.t()) :: {:ok, Recurso.t()} | {:error, atom()}
  def liberar(_codigo, _ubicacion, _cantidad, _id_necesidad), do: {:error, :no_implementado}

  @spec transferir(String.t(), String.t(), String.t(), pos_integer(), map()) ::
          {:ok, Recurso.t()} | {:error, atom()}
  def transferir(_codigo, _origen, _destino, _cantidad, _meta \\ %{}), do: {:error, :no_implementado}

  @spec consultar(String.t()) :: {:ok, Recurso.t()} | {:error, :no_existe}
  def consultar(_codigo), do: {:error, :no_implementado}

  @doc "Lista todos los recursos (usa Registry.select sobre la clave {:recurso, codigo})."
  @spec listar() :: [Recurso.t()]
  def listar, do: []

  ## Callbacks

  @impl true
  def init(%Recurso{} = recurso) do
    # TODO: si existe en disco una versión más reciente, usarla en vez del argumento.
    {:ok, recurso}
  end
end
