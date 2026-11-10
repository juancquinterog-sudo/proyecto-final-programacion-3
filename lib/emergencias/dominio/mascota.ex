defmodule Emergencias.Dominio.Mascota do
  @moduledoc """
  Reporte de mascota perdida o encontrada (req. 1.4.7).

  Tipo: `:perdida | :encontrada`. Estados: `:activa | :posible_coincidencia | :resuelta`.
  `pareja_id` guarda el reporte con el que se confirmó la coincidencia.
  """

  @enforce_keys [:id, :tipo, :especie, :zona, :estado]
  defstruct [
    :id,
    :tipo,
    :especie,
    :nombre,
    :color,
    :tamano,
    :zona,
    :contacto,
    :pareja_id,
    caracteristicas: MapSet.new(),
    estado: :activa
  ]

  @type t :: %__MODULE__{}

  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(_datos), do: {:error, :no_implementado}

  @spec cambiar_estado(t(), atom()) :: {:ok, t()} | {:error, atom()}
  def cambiar_estado(_mascota, _nuevo), do: {:error, :no_implementado}

  @doc "Cierra dos reportes relacionados (perdida + encontrada) como `:resuelta`."
  @spec confirmar_coincidencia(t(), t()) :: {:ok, {t(), t()}} | {:error, atom()}
  def confirmar_coincidencia(_perdida, _encontrada), do: {:error, :no_implementado}
end
