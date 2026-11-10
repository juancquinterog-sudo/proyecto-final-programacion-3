defmodule Emergencias.Dominio.Estadisticas do
  @moduledoc """
  Cálculos puros para `summary`, `critical_resources` y el reporte de albergues
  más ocupados. Incluye funciones recursivas propias sobre listas.
  """

  alias Emergencias.Dominio.{Albergue, Necesidad, Recurso}

  # --- RECURSIVAS (TODO) ---

  @doc "Suma recursiva de una lista de enteros (cabeza | cola)."
  @spec sumar([number()]) :: number()
  def sumar(_lista), do: 0

  @doc "Cuenta recursivamente cuántos elementos cumplen un predicado."
  @spec contar_si([term()], (term() -> boolean())) :: non_neg_integer()
  def contar_si(_lista, _predicado), do: 0

  @doc "Agrupa recursivamente una lista en un mapa `%{clave => [elementos]}`."
  @spec agrupar([term()], (term() -> term())) :: %{term() => [term()]}
  def agrupar(_lista, _fun_clave), do: %{}

  # --- Reportes ---

  @spec albergues_mas_ocupados([Albergue.t()], pos_integer()) :: [Albergue.t()]
  def albergues_mas_ocupados(albergues, _n), do: albergues

  @spec recursos_criticos([Recurso.t()], non_neg_integer()) :: [Recurso.t()]
  def recursos_criticos(recursos, _umbral), do: recursos

  @spec necesidades_pendientes([Necesidad.t()]) :: [Necesidad.t()]
  def necesidades_pendientes(necesidades), do: necesidades
end
