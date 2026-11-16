defmodule Emergencias.Dominio.Estadisticas do
  @moduledoc """
  Cálculos puros para `summary`, `critical_resources` y el reporte de albergues
  más ocupados. Incluye funciones recursivas propias sobre listas.
  """

  alias Emergencias.Dominio.{Albergue, Necesidad, Recurso}

  # --- RECURSIVAS ---

  @doc "Suma recursiva de una lista de enteros (cabeza | cola)."
  @spec sumar([number()]) :: number()
  def sumar([]), do: 0
  def sumar([cabeza | cola]), do: cabeza + sumar(cola)

  @doc "Cuenta recursivamente cuántos elementos cumplen un predicado."
  @spec contar_si([term()], (term() -> boolean())) :: non_neg_integer()
  def contar_si([], _predicado), do: 0

  def contar_si([cabeza | cola], predicado) do
    if(predicado.(cabeza), do: 1, else: 0) + contar_si(cola, predicado)
  end

  @doc "Agrupa recursivamente una lista en un mapa `%{clave => [elementos]}`."
  @spec agrupar([term()], (term() -> term())) :: %{term() => [term()]}
  def agrupar(lista, fun_clave), do: agrupar(lista, fun_clave, %{})

  defp agrupar([], _fun_clave, acum), do: Map.new(acum, fn {k, v} -> {k, Enum.reverse(v)} end)

  defp agrupar([cabeza | cola], fun_clave, acum),
    do: agrupar(cola, fun_clave, Map.update(acum, fun_clave.(cabeza), [cabeza], &[cabeza | &1]))

  # --- Reportes ---

  @spec albergues_mas_ocupados([Albergue.t()], pos_integer()) :: [Albergue.t()]
  def albergues_mas_ocupados(albergues, n) do
    albergues
    |> Enum.sort_by(fn a -> {-Albergue.porcentaje_ocupacion(a), a.codigo} end)
    |> Enum.take(n)
  end

  @spec recursos_criticos([Recurso.t()], non_neg_integer()) :: [Recurso.t()]
  def recursos_criticos(recursos, umbral) do
    recursos
    |> Enum.filter(fn r -> Recurso.total(r) <= umbral end)
    |> Enum.sort_by(fn r -> {Recurso.total(r), r.codigo} end)
  end

  @spec necesidades_pendientes([Necesidad.t()]) :: [Necesidad.t()]
  def necesidades_pendientes(necesidades),
    do: necesidades |> Enum.filter(&Necesidad.pendiente?/1) |> Necesidad.ordenar()
end
