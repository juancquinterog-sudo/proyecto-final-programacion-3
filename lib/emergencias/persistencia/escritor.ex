defmodule Emergencias.Persistencia.Escritor do
  @moduledoc """
  GenServer que SERIALIZA todas las escrituras en disco: aunque muchos procesos
  guarden a la vez, el archivo nunca se corrompe por escrituras entrecruzadas.

  Recomendación: escribir primero a `archivo.tmp` y luego `File.rename/2`
  (escritura atómica) cuando se reescribe un archivo completo.
  """
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Anexa una línea de texto a un archivo."
  @spec anexar(Path.t(), String.t()) :: :ok | {:error, term()}
  def anexar(_ruta, _linea), do: {:error, :no_implementado}

  @doc "Reemplaza el contenido completo de un archivo."
  @spec reemplazar(Path.t(), [String.t()]) :: :ok | {:error, term()}
  def reemplazar(_ruta, _lineas), do: {:error, :no_implementado}

  @impl true
  def init(:ok) do
    # TODO: File.mkdir_p!(data_dir) al arrancar
    {:ok, %{}}
  end
end
