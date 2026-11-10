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

  def umbral, do: @umbral

  @spec puntaje(Mascota.t(), Mascota.t()) :: float()
  def puntaje(_a, _b), do: 0.0

  @doc "Para cada perdida activa, devuelve las encontradas candidatas ordenadas por puntaje."
  @spec buscar_coincidencias([Mascota.t()]) :: [{Mascota.t(), Mascota.t(), float()}]
  def buscar_coincidencias(_mascotas), do: []
end
