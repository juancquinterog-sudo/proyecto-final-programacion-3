defmodule Emergencias.Dominio.Albergue do
  @moduledoc """
  Albergue (req. 1.4.8). Los ocupantes se guardan en un `MapSet` de documentos:
  evita duplicados (la misma persona no ingresa dos veces) y `MapSet.size/1`
  da la ocupación actual. Ocupación <= capacidad SIEMPRE.
  """

  alias Emergencias.Dominio.Validaciones

  @enforce_keys [:codigo, :nombre, :zona, :capacidad]
  defstruct [:codigo, :nombre, :zona, :capacidad, ocupantes: MapSet.new()]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          zona: String.t(),
          capacidad: non_neg_integer(),
          ocupantes: MapSet.t(String.t())
        }

  @doc "Crea un albergue vacío. `datos`: `:codigo`, `:nombre`, `:zona`, `:capacidad`."
  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    with {:ok, codigo} <- Validaciones.texto_no_vacio(Map.get(datos, :codigo)),
         {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre)),
         {:ok, zona} <- Validaciones.texto_no_vacio(Map.get(datos, :zona)),
         {:ok, capacidad} <- Validaciones.entero_no_negativo(Map.get(datos, :capacidad)) do
      {:ok, %__MODULE__{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad}}
    end
  end

  @spec ocupacion(t()) :: non_neg_integer()
  def ocupacion(%__MODULE__{ocupantes: o}), do: MapSet.size(o)

  @spec cupos(t()) :: non_neg_integer()
  def cupos(%__MODULE__{capacidad: c} = a), do: max(c - ocupacion(a), 0)

  @spec porcentaje_ocupacion(t()) :: float()
  def porcentaje_ocupacion(%__MODULE__{capacidad: 0}), do: 0.0
  def porcentaje_ocupacion(%__MODULE__{capacidad: c} = a), do: ocupacion(a) * 100 / c

  @doc "Registra el ingreso de una persona (por documento) si hay cupo."
  @spec ingresar(t(), String.t()) :: {:ok, t()} | {:error, :sin_cupo | :ya_ingresado | :texto_vacio}
  def ingresar(%__MODULE__{} = albergue, documento) do
    with {:ok, documento} <- Validaciones.texto_no_vacio(documento) do
      cond do
        MapSet.member?(albergue.ocupantes, documento) -> {:error, :ya_ingresado}
        cupos(albergue) == 0 -> {:error, :sin_cupo}
        true -> {:ok, %{albergue | ocupantes: MapSet.put(albergue.ocupantes, documento)}}
      end
    end
  end

  @doc "Registra la salida de una persona."
  @spec salir(t(), String.t()) :: {:ok, t()} | {:error, :no_esta_en_albergue | :texto_vacio}
  def salir(%__MODULE__{} = albergue, documento) do
    with {:ok, documento} <- Validaciones.texto_no_vacio(documento) do
      if MapSet.member?(albergue.ocupantes, documento) do
        {:ok, %{albergue | ocupantes: MapSet.delete(albergue.ocupantes, documento)}}
      else
        {:error, :no_esta_en_albergue}
      end
    end
  end
end
