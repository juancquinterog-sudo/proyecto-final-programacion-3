defmodule Emergencias.Dominio.Albergue do
  @moduledoc """
  Albergue (req. 1.4.8). Los ocupantes se guardan en un `MapSet` de documentos:
  evita duplicados (la misma persona no ingresa dos veces) y `MapSet.size/1`
  da la ocupación actual. Ocupación <= capacidad SIEMPRE.
  """

  @enforce_keys [:codigo, :nombre, :zona, :capacidad]
  defstruct [:codigo, :nombre, :zona, :capacidad, ocupantes: MapSet.new()]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          zona: String.t(),
          capacidad: non_neg_integer(),
          ocupantes: MapSet.t(String.t())
        }

  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(_datos), do: {:error, :no_implementado}

  @spec ocupacion(t()) :: non_neg_integer()
  def ocupacion(%__MODULE__{ocupantes: o}), do: MapSet.size(o)

  @spec cupos(t()) :: non_neg_integer()
  def cupos(%__MODULE__{capacidad: c} = a), do: c - ocupacion(a)

  @spec porcentaje_ocupacion(t()) :: float()
  def porcentaje_ocupacion(%__MODULE__{capacidad: 0}), do: 0.0
  def porcentaje_ocupacion(%__MODULE__{capacidad: c} = a), do: ocupacion(a) * 100 / c

  @spec ingresar(t(), String.t()) :: {:ok, t()} | {:error, :sin_cupo | :ya_ingresado}
  def ingresar(_albergue, _documento), do: {:error, :no_implementado}

  @spec salir(t(), String.t()) :: {:ok, t()} | {:error, :no_esta_en_albergue}
  def salir(_albergue, _documento), do: {:error, :no_implementado}
end
