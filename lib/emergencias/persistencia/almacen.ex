defmodule Emergencias.Persistencia.Almacen do
  @moduledoc """
  Fachada de persistencia en ARCHIVOS DE TEXTO PLANO (req. 1.4.9).

  Una línea por registro, campos separados por `|` (ver `Codec`). Archivos en
  `Application.get_env(:emergencias, :data_dir)`:

  | archivo            | contenido                                   |
  |--------------------|---------------------------------------------|
  | usuarios.txt       | usuarios (contraseña como hash)             |
  | zonas.txt          | zonas, sectores y puntos (líneas Z/S/P)     |
  | necesidades.txt    | necesidades y sus asignaciones              |
  | recursos.txt       | recursos y existencias por ubicación        |
  | movimientos.txt    | historial de movimientos de inventario      |
  | personas.txt       | personas e historial de estados             |
  | mensajes.txt       | mensajes entre familiares                   |
  | mascotas.txt       | reportes de mascotas                        |
  | albergues.txt      | albergues y ocupantes                       |
  | actividad.log      | bitácora de actividad por usuario           |

  Lectura: directa (`File.stream!` + `Codec`). Escritura: SIEMPRE vía `Escritor`.
  """

  @entidades ~w(usuarios zonas necesidades recursos movimientos personas mensajes mascotas albergues)a

  def entidades, do: @entidades

  @spec ruta(atom()) :: String.t()
  def ruta(entidad) do
    Path.join(Application.get_env(:emergencias, :data_dir, "data"), "#{entidad}.txt")
  end

  @doc "Lee todos los registros de una entidad como structs. `{:ok, lista} | {:error, razon}`."
  @spec cargar(atom()) :: {:ok, [term()]} | {:error, term()}
  def cargar(_entidad), do: {:error, :no_implementado}

  @doc "Reemplaza el archivo completo con los registros dados."
  @spec guardar(atom(), [term()]) :: :ok | {:error, term()}
  def guardar(_entidad, _registros), do: {:error, :no_implementado}

  @doc "Agrega un registro al final del archivo."
  @spec agregar(atom(), term()) :: :ok | {:error, term()}
  def agregar(_entidad, _registro), do: {:error, :no_implementado}
end
