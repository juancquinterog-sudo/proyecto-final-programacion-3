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
  def nuevo(datos) when is_map(datos) do
    id = datos[:id] || datos["id"]
    tipo = datos[:tipo] || datos["tipo"]
    especie = datos[:especie] || datos["especie"]
    zona = datos[:zona] || datos["zona"]
    estado = datos[:estado] || datos["estado"] || :activa

    if id && tipo && especie && zona do
      mascota = %__MODULE__{
        id: id,
        tipo: tipo,
        especie: especie,
        nombre: datos[:nombre] || datos["nombre"],
        color: datos[:color] || datos["color"],
        tamano: datos[:tamano] || datos["tamano"],
        zona: zona,
        contacto: datos[:contacto] || datos["contacto"],
        pareja_id: datos[:pareja_id] || datos["pareja_id"],
        caracteristicas: datos[:caracteristicas] || datos["caracteristicas"] || MapSet.new(),
        estado: estado
      }
      {:ok, mascota}
    else
      {:error, :datos_incompletos}
    end
  end

  @spec cambiar_estado(t(), atom()) :: {:ok, t()} | {:error, atom()}
  def cambiar_estado(%__MODULE__{} = mascota, nuevo_estado) when nuevo_estado in [:activa, :posible_coincidencia, :resuelta] do
    {:ok, %{mascota | estado: nuevo_estado}}
  end
  def cambiar_estado(%__MODULE__{}, _nuevo), do: {:error, :estado_invalido}

  @doc "Cierra dos reportes relacionados (perdida + encontrada) como `:resuelta`."
  @spec confirmar_coincidencia(t(), t()) :: {:ok, {t(), t()}} | {:error, atom()}
  def confirmar_coincidencia(%__MODULE__{} = perdida, %__MODULE__{} = encontrada) do
    p_actualizada = %{perdida | estado: :resuelta, pareja_id: encontrada.id}
    e_actualizada = %{encontrada | estado: :resuelta, pareja_id: perdida.id}
    {:ok, {p_actualizada, e_actualizada}}
  end
end
