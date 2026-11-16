defmodule Emergencias.Dominio.Similitud do
  @moduledoc """
  Algoritmo de coincidencia entre mascotas (req. 1.4.7). Puro y probable.

  Criterio propuesto (ajustable por el equipo), puntaje de 0.0 a 1.0:

  | atributo         | peso | regla                                            |
  |------------------|:----:|--------------------------------------------------|
  | especie          | req. | si difiere -> puntaje 0.0 (descarta)              |
  | tipo de reporte  | req. | solo se comparan `:perdida` con `:encontrada`     |
  | zona             | 0.25 | misma zona = 1.0, distinta = 0.0                  |
  | color            | 0.25 | igual = 1.0, distinto = 0.0                       |
  | tamaño           | 0.20 | igual = 1.0, adyacente (pequeña/mediana) = 0.5    |
  | características  | 0.20 | índice de Jaccard sobre `MapSet` de palabras      |
  | nombre           | 0.10 | igual (si ambos lo conocen) = 1.0                 |

  Umbral para marcar `:posible_coincidencia`: `>= 0.60`.
  """

  alias Emergencias.Dominio.Mascota

  @umbral 0.60
  @tamanos [:pequena, :mediana, :grande]

  def umbral, do: @umbral

  @spec puntaje(Mascota.t(), Mascota.t()) :: float()
  def puntaje(%Mascota{tipo: t1}, %Mascota{tipo: t2}) when t1 == t2, do: 0.0

  def puntaje(%Mascota{} = a, %Mascota{} = b) do
    if norm(a.especie) != norm(b.especie) do
      0.0
    else
      total =
        0.25 * igual(a.zona, b.zona) + 0.25 * igual(a.color, b.color) +
          0.20 * tamano(a.tamano, b.tamano) + 0.20 * jaccard(a.caracteristicas, b.caracteristicas) +
          0.10 * igual(a.nombre, b.nombre)

      Float.round(total, 4)
    end
  end

  @doc "Índice de Jaccard entre dos `MapSet`: |A ∩ B| / |A ∪ B| (0.0 si ambos están vacíos)."
  @spec jaccard(MapSet.t(), MapSet.t()) :: float()
  def jaccard(a, b) do
    union = MapSet.size(MapSet.union(a, b))
    if union == 0, do: 0.0, else: MapSet.size(MapSet.intersection(a, b)) / union
  end

  @doc "Para cada perdida no resuelta, devuelve las encontradas candidatas (puntaje >= umbral), de mayor a menor."
  @spec buscar_coincidencias([Mascota.t()]) :: [{Mascota.t(), Mascota.t(), float()}]
  def buscar_coincidencias(mascotas) do
    abiertas = Enum.reject(mascotas, &(&1.estado == :resuelta))
    perdidas = Enum.filter(abiertas, &(&1.tipo == :perdida))
    encontradas = Enum.filter(abiertas, &(&1.tipo == :encontrada))

    for p <- perdidas, e <- encontradas, (puntos = puntaje(p, e)) >= @umbral do
      {p, e, puntos}
    end
    |> Enum.sort_by(fn {p, e, puntos} -> {-puntos, p.id, e.id} end)
  end

  defp norm(nil), do: nil
  defp norm(v), do: v |> to_string() |> String.trim() |> String.downcase()

  defp igual(a, b) do
    if norm(a) != nil and norm(a) == norm(b), do: 1.0, else: 0.0
  end

  defp tamano(a, b) do
    with ia when ia != nil <- Enum.find_index(@tamanos, &(&1 == a)),
         ib when ib != nil <- Enum.find_index(@tamanos, &(&1 == b)) do
      case abs(ia - ib) do
        0 -> 1.0
        1 -> 0.5
        _ -> 0.0
      end
    else
      _ -> 0.0
    end
  end
end
