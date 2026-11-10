defmodule Emergencias.Servidores.UsuarioServer do
  @moduledoc """
  Usuarios registrados y sesiones conectadas (req. 1.4.1 y 1.4.2).

  Estado: `%{usuarios: %{nombre_usuario => Usuario}, conectados: MapSet}`.

    * `conectar/4`    - registro automático si no existe; si existe valida contraseña.
    * `desconectar/1` - saca al usuario de `conectados`.
    * `obtener/1`     - consulta un usuario (para validar permisos).
    * Toda acción exitosa se reporta a `Procesos.Bitacora`.
  """
  use GenServer

  ## API pública (cliente)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec conectar(String.t(), String.t(), atom() | nil, String.t() | nil) ::
          {:ok, map()} | {:error, atom()}
  def conectar(_usuario, _contrasena, _tipo, _zona), do: {:error, :no_implementado}

  @spec desconectar(String.t()) :: :ok | {:error, atom()}
  def desconectar(_usuario), do: {:error, :no_implementado}

  @spec obtener(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def obtener(_usuario), do: {:error, :no_implementado}

  ## Callbacks (servidor)

  @impl true
  def init(:ok) do
    # TODO: cargar el estado desde el archivo de texto plano (Persistencia.Almacen)
    # para recuperarse tras un reinicio del supervisor.
    {:ok, %{}}
  end
end
