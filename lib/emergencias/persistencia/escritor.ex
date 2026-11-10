defmodule Emergencias.Persistencia.Escritor do
  @moduledoc """
  GenServer que SERIALIZA todas las escrituras en disco: aunque muchos procesos
  guarden a la vez, las líneas nunca se entrecruzan ni el archivo se corrompe,
  porque las peticiones se atienden de una en una desde el buzón.

  * `anexar/2`    agrega texto al final del archivo.
  * `reemplazar/2` reescribe el archivo completo de forma atómica: escribe en
    `archivo.tmp` y luego lo renombra, así nunca queda un archivo a medias.
  """
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Anexa una línea (o varias, separadas por salto) al final de un archivo."
  @spec anexar(Path.t(), String.t()) :: :ok | {:error, term()}
  def anexar(ruta, linea) when is_binary(linea) do
    GenServer.call(__MODULE__, {:anexar, ruta, linea})
  end

  @doc "Reemplaza el contenido completo de un archivo con las líneas dadas."
  @spec reemplazar(Path.t(), [String.t()]) :: :ok | {:error, term()}
  def reemplazar(ruta, lineas) when is_list(lineas) do
    GenServer.call(__MODULE__, {:reemplazar, ruta, lineas})
  end

  ## Callbacks

  @impl true
  def init(:ok) do
    File.mkdir_p(Application.get_env(:emergencias, :data_dir, "data"))
    {:ok, %{}}
  end

  @impl true
  def handle_call({:anexar, ruta, linea}, _from, estado) do
    resultado =
      with :ok <- File.mkdir_p(Path.dirname(ruta)) do
        File.write(ruta, linea <> "\n", [:append])
      end

    {:reply, resultado, estado}
  end

  def handle_call({:reemplazar, ruta, lineas}, _from, estado) do
    temporal = ruta <> ".tmp"
    contenido = Enum.map_join(lineas, "", fn linea -> linea <> "\n" end)

    resultado =
      with :ok <- File.mkdir_p(Path.dirname(ruta)),
           :ok <- File.write(temporal, contenido) do
        File.rename(temporal, ruta)
      end

    {:reply, resultado, estado}
  end
end
