defmodule Emergencias.Persistencia.Codec do
  @moduledoc """
  Conversión struct <-> línea de texto (`a_linea/1`, `de_linea/1`) para cada
  entidad. Mantiene el dominio puro: los structs no saben de archivos.

  Formato: campos separados por `|`; el `|` y el salto de línea dentro de un
  campo se escapan (`\\|`, `\\n`). Listas internas separadas por `;` y pares
  clave:valor por `:`.
  """

  @spec a_linea(struct()) :: String.t()
  def a_linea(_registro), do: ""

  @spec de_linea(atom(), String.t()) :: {:ok, struct()} | {:error, :linea_invalida}
  def de_linea(_entidad, _linea), do: {:error, :no_implementado}

  @doc "Separa una línea respetando los `|` escapados (RECURSIVA sobre los caracteres)."
  @spec dividir(String.t()) :: [String.t()]
  def dividir(_linea), do: []

  @spec escapar(String.t()) :: String.t()
  def escapar(texto), do: texto

  @spec desescapar(String.t()) :: String.t()
  def desescapar(texto), do: texto
end
