defmodule Emergencias.Servidores.AlbergueServer do
  @moduledoc """
  UN proceso por albergue (req. 1.4.8). Serializa ingresos y salidas, de modo
  que dos personas que llegan a la vez al último cupo no superen la capacidad.

  Registro: `{:via, Registry, {Emergencias.Registry, {:albergue, codigo}}}`.
  Supervisado por `Emergencias.AlbergueDinamico` (DynamicSupervisor).
  Persistencia: igual que `RecursoServer` (foto completa bajo lock global).
  """
  use GenServer, restart: :transient

  alias Emergencias.Dominio.Albergue
  alias Emergencias.Persistencia.Almacen

  @registry Emergencias.Registry
  @supervisor Emergencias.AlbergueDinamico

  @spec registrar(Albergue.t()) :: {:ok, pid()} | {:error, atom()}
  def registrar(%Albergue{} = albergue) do
    with {:ok, pid} <- iniciar(albergue) do
      persistir()
      {:ok, pid}
    end
  end

  @doc "Crea el proceso SIN persistir (lo usa el `Restaurador`)."
  @spec restaurar(Albergue.t()) :: {:ok, pid()} | {:error, atom()}
  def restaurar(%Albergue{} = albergue), do: iniciar(albergue)

  defp iniciar(albergue) do
    case DynamicSupervisor.start_child(@supervisor, {__MODULE__, albergue}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _}} -> {:error, :id_duplicado}
      {:error, razon} -> {:error, razon}
    end
  end

  def start_link(%Albergue{} = albergue) do
    GenServer.start_link(__MODULE__, albergue, name: via(albergue.codigo))
  end

  def via(codigo), do: {:via, Registry, {@registry, {:albergue, codigo}}}

  @spec consultar(String.t()) :: {:ok, Albergue.t()} | {:error, :no_existe}
  def consultar(codigo), do: con_albergue(codigo, :consultar)

  @spec registrar_entrada(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_entrada(codigo, documento), do: operar(codigo, {:ingresar, documento})

  @spec registrar_salida(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_salida(codigo, documento), do: operar(codigo, {:salir, documento})

  @spec listar() :: [Albergue.t()]
  def listar do
    @registry
    |> Registry.select([{{{:albergue, :_}, :"$1", :_}, [], [:"$1"]}])
    |> Enum.flat_map(fn pid ->
      case llamar(pid, :consultar) do
        {:ok, albergue} -> [albergue]
        _ -> []
      end
    end)
    |> Enum.sort_by(& &1.codigo)
  end

  @spec persistir() :: :ok | {:error, term()}
  def persistir do
    :global.trans({{:persistir, :albergues}, self()}, fn ->
      Almacen.guardar(:albergues, listar())
    end)
  end

  defp operar(codigo, peticion) do
    resultado = con_albergue(codigo, peticion)
    if match?({:ok, _}, resultado), do: persistir()
    resultado
  end

  defp con_albergue(codigo, peticion) do
    case Registry.lookup(@registry, {:albergue, codigo}) do
      [{pid, _}] -> llamar(pid, peticion)
      [] -> {:error, :no_existe}
    end
  end

  defp llamar(pid, peticion) do
    GenServer.call(pid, peticion)
  catch
    :exit, _ -> {:error, :no_existe}
  end

  @impl true
  def init(%Albergue{} = albergue), do: {:ok, albergue}

  @impl true
  def handle_call(:consultar, _from, albergue), do: {:reply, {:ok, albergue}, albergue}

  def handle_call({:ingresar, documento}, _from, albergue),
    do: aplicar(albergue, Albergue.ingresar(albergue, documento))

  def handle_call({:salir, documento}, _from, albergue),
    do: aplicar(albergue, Albergue.salir(albergue, documento))

  defp aplicar(_anterior, {:ok, nuevo}), do: {:reply, {:ok, nuevo}, nuevo}
  defp aplicar(anterior, {:error, _} = error), do: {:reply, error, anterior}
end
