defmodule Emergencias.Servidores.RecursoServer do
  @moduledoc """
  UN proceso por recurso (req. 1.4.5). Es el corazón de la REGLA DE CONCURRENCIA
  OBLIGATORIA: todas las solicitudes sobre el mismo recurso llegan al buzón
  (mailbox) de este proceso y se atienden de una en una, así que
  `existencias` nunca queda negativa ni se sobre-asigna.

  Registro por nombre: `{:via, Registry, {Emergencias.Registry, {:recurso, codigo}}}`.
  Se crea con `DynamicSupervisor.start_child(Emergencias.RecursoDinamico, ...)`.

  Persistencia: tras cada cambio exitoso el CLIENTE llama a `persistir/0`, que
  toma una foto de todos los recursos y reescribe `recursos.txt` y
  `movimientos.txt` dentro de un lock global (`:global.trans`). Así dos
  escrituras nunca se pisan con una foto vieja. (No se persiste dentro del
  GenServer para evitar que dos recursos se llamen entre sí y se bloqueen.)
  """
  use GenServer, restart: :transient

  alias Emergencias.Dominio.Recurso
  alias Emergencias.Persistencia.Almacen

  @registry Emergencias.Registry
  @supervisor Emergencias.RecursoDinamico

  ## API

  @doc "Crea el proceso del recurso bajo el DynamicSupervisor y lo persiste."
  @spec registrar(Recurso.t()) :: {:ok, pid()} | {:error, atom()}
  def registrar(%Recurso{} = recurso) do
    with {:ok, pid} <- iniciar(recurso) do
      persistir()
      {:ok, pid}
    end
  end

  @doc "Crea el proceso SIN persistir (lo usa el `Restaurador` al arrancar)."
  @spec restaurar(Recurso.t()) :: {:ok, pid()} | {:error, atom()}
  def restaurar(%Recurso{} = recurso), do: iniciar(recurso)

  defp iniciar(recurso) do
    case DynamicSupervisor.start_child(@supervisor, {__MODULE__, recurso}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:error, :id_duplicado}
      {:error, razon} -> {:error, razon}
    end
  end

  def start_link(%Recurso{} = recurso) do
    GenServer.start_link(__MODULE__, recurso, name: via(recurso.codigo))
  end

  def via(codigo), do: {:via, Registry, {@registry, {:recurso, codigo}}}

  @spec entrada(String.t(), String.t(), pos_integer(), map()) ::
          {:ok, Recurso.t()} | {:error, atom()}
  def entrada(codigo, ubicacion, cantidad, meta \\ %{}),
    do: operar(codigo, {:entrada, ubicacion, cantidad, meta})

  @spec salida(String.t(), String.t(), pos_integer(), map()) ::
          {:ok, Recurso.t()} | {:error, atom()}
  def salida(codigo, ubicacion, cantidad, meta \\ %{}),
    do: operar(codigo, {:salida, ubicacion, cantidad, meta})

  @doc "Descuenta para una necesidad. Todo-o-nada: `{:error, :stock_insuficiente}` si no alcanza."
  @spec reservar(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, Recurso.t()} | {:error, :stock_insuficiente | atom()}
  def reservar(codigo, ubicacion, cantidad, id_necesidad),
    do: operar(codigo, {:reservar, ubicacion, cantidad, id_necesidad})

  @doc "Devuelve lo reservado (rollback si falla el registro en la necesidad)."
  @spec liberar(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, Recurso.t()} | {:error, atom()}
  def liberar(codigo, ubicacion, cantidad, id_necesidad),
    do: operar(codigo, {:liberar, ubicacion, cantidad, id_necesidad})

  @spec transferir(String.t(), String.t(), String.t(), pos_integer(), map()) ::
          {:ok, Recurso.t()} | {:error, atom()}
  def transferir(codigo, origen, destino, cantidad, meta \\ %{}),
    do: operar(codigo, {:transferir, origen, destino, cantidad, meta})

  @spec consultar(String.t()) :: {:ok, Recurso.t()} | {:error, :no_existe}
  def consultar(codigo) do
    case Registry.lookup(@registry, {:recurso, codigo}) do
      [{pid, _}] -> llamar(pid, :consultar)
      [] -> {:error, :no_existe}
    end
  end

  @doc "Lista todos los recursos (usa Registry.select sobre la clave {:recurso, codigo})."
  @spec listar() :: [Recurso.t()]
  def listar do
    @registry
    |> Registry.select([{{{:recurso, :_}, :"$1", :_}, [], [:"$1"]}])
    |> Enum.flat_map(fn pid ->
      case llamar(pid, :consultar) do
        {:ok, recurso} -> [recurso]
        _ -> []
      end
    end)
    |> Enum.sort_by(& &1.codigo)
  end

  @doc "Reescribe `recursos.txt` y `movimientos.txt` con el estado actual (serializado con un lock global)."
  @spec persistir() :: :ok | {:error, term()}
  def persistir do
    :global.trans({{:persistir, :recursos}, self()}, fn ->
      recursos = listar()
      movimientos = Enum.flat_map(recursos, fn r -> Enum.reverse(r.historial) end)

      with :ok <- Almacen.guardar(:recursos, recursos) do
        Almacen.guardar(:movimientos, movimientos)
      end
    end)
  end

  ## Operaciones: llamada al proceso + persistencia si hubo cambio

  defp operar(codigo, peticion) do
    case Registry.lookup(@registry, {:recurso, codigo}) do
      [{pid, _}] ->
        resultado = llamar(pid, peticion)
        if match?({:ok, _}, resultado), do: persistir()
        resultado

      [] ->
        {:error, :no_existe}
    end
  end

  defp llamar(pid, peticion) do
    GenServer.call(pid, peticion)
  catch
    :exit, _ -> {:error, :no_existe}
  end

  ## Callbacks

  @impl true
  def init(%Recurso{} = recurso), do: {:ok, recurso}

  @impl true
  def handle_call(:consultar, _from, recurso), do: {:reply, {:ok, recurso}, recurso}

  def handle_call({:entrada, ubicacion, cantidad, meta}, _from, recurso),
    do: aplicar(recurso, Recurso.entrada(recurso, ubicacion, cantidad, con_fecha(meta)))

  def handle_call({:salida, ubicacion, cantidad, meta}, _from, recurso),
    do: aplicar(recurso, Recurso.salida(recurso, ubicacion, cantidad, con_fecha(meta)))

  def handle_call({:reservar, ubicacion, cantidad, id_necesidad}, _from, recurso),
    do:
      aplicar(
        recurso,
        Recurso.asignar(recurso, ubicacion, cantidad, id_necesidad, con_fecha(%{}))
      )

  def handle_call({:liberar, ubicacion, cantidad, id_necesidad}, _from, recurso) do
    meta = con_fecha(%{referencia: "liberacion:" <> id_necesidad})
    aplicar(recurso, Recurso.entrada(recurso, ubicacion, cantidad, meta))
  end

  def handle_call({:transferir, origen, destino, cantidad, meta}, _from, recurso),
    do: aplicar(recurso, Recurso.transferir(recurso, origen, destino, cantidad, con_fecha(meta)))

  defp aplicar(_anterior, {:ok, nuevo}), do: {:reply, {:ok, nuevo}, nuevo}
  defp aplicar(anterior, {:error, _} = error), do: {:reply, error, anterior}

  defp con_fecha(meta),
    do: Map.put_new(meta, :fecha, DateTime.utc_now() |> DateTime.truncate(:second))
end
