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

  Lectura: directa (`File.read` + `Codec`). Escritura: SIEMPRE vía `Escritor`.
  Si el archivo no existe, `cargar/1` devuelve `{:ok, []}` (primera ejecución).
  """

  alias Emergencias.Persistencia.{Codec, Escritor}

  @entidades ~w(usuarios zonas necesidades recursos movimientos personas mensajes mascotas albergues)a

  def entidades, do: @entidades

  @spec ruta(atom()) :: String.t()
  def ruta(entidad) do
    Path.join(Application.get_env(:emergencias, :data_dir, "data"), "#{entidad}.txt")
  end

  @doc "Lee todos los registros de una entidad como structs. `{:ok, lista} | {:error, razon}`."
  @spec cargar(atom()) :: {:ok, [term()]} | {:error, term()}
  def cargar(entidad) when entidad in @entidades do
    case File.read(ruta(entidad)) do
      {:ok, contenido} ->
        lineas =
          contenido
          |> String.split(["\r\n", "\n"])
          |> Enum.reject(fn linea -> String.trim(linea) == "" end)

        Codec.de_lineas(entidad, lineas)

      {:error, :enoent} ->
        {:ok, []}

      {:error, razon} ->
        {:error, razon}
    end
  end

  def cargar(_entidad), do: {:error, :entidad_desconocida}

  @doc "Reemplaza el archivo completo con los registros dados."
  @spec guardar(atom(), [term()]) :: :ok | {:error, term()}
  def guardar(entidad, registros) when entidad in @entidades and is_list(registros) do
    lineas = Enum.flat_map(registros, &Codec.a_lineas/1)
    Escritor.reemplazar(ruta(entidad), lineas)
  end

  def guardar(_entidad, _registros), do: {:error, :entidad_desconocida}

  @doc "Agrega un registro al final del archivo (no usar para `:zonas`; allí usar `guardar/2`)."
  @spec agregar(atom(), term()) :: :ok | {:error, term()}
  def agregar(entidad, registro) when entidad in @entidades and entidad != :zonas do
    Escritor.anexar(ruta(entidad), registro |> Codec.a_lineas() |> Enum.join("\n"))
  end

  def agregar(_entidad, _registro), do: {:error, :entidad_desconocida}
end
