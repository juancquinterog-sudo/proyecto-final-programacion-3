defmodule Emergencias.Servidores.UsuarioServer do
  @moduledoc """
  Usuarios registrados y sesiones conectadas (req. 1.4.1 y 1.4.2).

  Estado: `%{usuarios: %{nombre_usuario => Usuario}, conectados: MapSet}`.

    * `conectar/4`    - si el usuario NO existe se registra automáticamente (exige
      tipo y zona); si existe valida la contraseña.
    * `desconectar/1` - lo saca de `conectados`.
    * `obtener/1`     - consulta un usuario.

  Persistencia: al registrar se agrega la línea a `usuarios.txt` ANTES de
  actualizar el estado; en `init/1` se recarga el archivo, así los usuarios
  sobreviven a un reinicio del proceso. Las sesiones (`conectados`) no se
  persisten: tras un reinicio hay que volver a conectarse.
  """
  use GenServer

  require Logger

  alias Emergencias.Dominio.{Usuario, Validaciones}
  alias Emergencias.Persistencia.Almacen

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec conectar(String.t(), String.t(), String.t() | atom() | nil, String.t() | nil) ::
          {:ok, Usuario.t(), :registrado | :autenticado} | {:error, term()}
  def conectar(usuario, contrasena, tipo, zona),
    do: GenServer.call(__MODULE__, {:conectar, usuario, contrasena, tipo, zona})

  @spec desconectar(String.t()) :: :ok | {:error, :no_conectado}
  def desconectar(usuario), do: GenServer.call(__MODULE__, {:desconectar, usuario})

  @spec obtener(String.t()) :: {:ok, Usuario.t()} | {:error, :no_existe}
  def obtener(usuario), do: GenServer.call(__MODULE__, {:obtener, usuario})

  @spec conectado?(String.t()) :: boolean()
  def conectado?(usuario), do: GenServer.call(__MODULE__, {:conectado?, usuario})

  @spec listar_conectados() :: [String.t()]
  def listar_conectados, do: GenServer.call(__MODULE__, :listar_conectados)

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    usuarios =
      case Almacen.cargar(:usuarios) do
        {:ok, lista} ->
          Map.new(lista, fn usuario -> {usuario.nombre_usuario, usuario} end)

        {:error, razon} ->
          Logger.warning("No se pudo cargar usuarios.txt: #{inspect(razon)}")
          %{}
      end

    {:ok, %{usuarios: usuarios, conectados: MapSet.new()}}
  end

  @impl true
  def handle_call({:conectar, usuario, contrasena, tipo, zona}, _from, estado) do
    with {:ok, nombre} <- Validaciones.texto_no_vacio(usuario),
         {:ok, clave} <- Validaciones.texto_no_vacio(contrasena),
         {:ok, encontrado, como, nuevo_estado} <- entrar(nombre, clave, tipo, zona, estado) do
      {:reply, {:ok, encontrado, como}, nuevo_estado}
    else
      {:error, _razon} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:desconectar, usuario}, _from, estado) do
    if MapSet.member?(estado.conectados, usuario) do
      {:reply, :ok, %{estado | conectados: MapSet.delete(estado.conectados, usuario)}}
    else
      {:reply, {:error, :no_conectado}, estado}
    end
  end

  def handle_call({:obtener, usuario}, _from, estado) do
    resultado =
      case Map.fetch(estado.usuarios, usuario) do
        {:ok, encontrado} -> {:ok, encontrado}
        :error -> {:error, :no_existe}
      end

    {:reply, resultado, estado}
  end

  def handle_call({:conectado?, usuario}, _from, estado),
    do: {:reply, MapSet.member?(estado.conectados, usuario), estado}

  def handle_call(:listar_conectados, _from, estado),
    do: {:reply, estado.conectados |> MapSet.to_list() |> Enum.sort(), estado}

  ## Privadas

  defp entrar(nombre, clave, tipo, zona, estado) do
    case Map.fetch(estado.usuarios, nombre) do
      {:ok, existente} ->
        with :ok <- Usuario.autenticar(existente, clave) do
          {:ok, existente, :autenticado, marcar_conectado(estado, nombre)}
        end

      :error ->
        registrar(nombre, clave, tipo, zona, estado)
    end
  end

  defp registrar(_nombre, _clave, nil, _zona, _estado), do: {:error, :faltan_datos_registro}
  defp registrar(_nombre, _clave, _tipo, nil, _estado), do: {:error, :faltan_datos_registro}

  defp registrar(nombre, clave, tipo, zona, estado) do
    with {:ok, zona} <- zona_valida(zona),
         {:ok, nuevo} <-
           Usuario.nuevo(%{nombre_usuario: nombre, contrasena: clave, tipo: tipo, zona: zona}),
         :ok <- persistir(nuevo) do
      con_usuario = %{estado | usuarios: Map.put(estado.usuarios, nombre, nuevo)}
      {:ok, nuevo, :registrado, marcar_conectado(con_usuario, nombre)}
    end
  end

  defp zona_valida(zona) do
    case Validaciones.texto_no_vacio(zona) do
      {:ok, texto} -> {:ok, texto}
      {:error, _} -> {:error, :zona_requerida}
    end
  end

  defp persistir(usuario) do
    case Almacen.agregar(:usuarios, usuario) do
      :ok -> :ok
      {:error, razon} -> {:error, {:persistencia, razon}}
    end
  end

  defp marcar_conectado(estado, nombre),
    do: %{estado | conectados: MapSet.put(estado.conectados, nombre)}
end
