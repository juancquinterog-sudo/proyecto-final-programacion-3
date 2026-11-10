defmodule Emergencias.Dominio.Necesidad do
  @moduledoc """
  Necesidad puntual de ayuda (req. 1.4.4). Módulo puro.

  Tipos: `:agua | :alimentos | :medicamentos | :primeros_auxilios | :refugio |
  :transporte | :rescate | :otra`.

  Prioridad (`:critica > :alta > :media > :baja`) NO es informativa: se usa en
  `insertar_por_prioridad/2` y `ordenar/1` para decidir a quién atender primero.
  """

  @prioridades [:critica, :alta, :media, :baja]

  @enforce_keys [:id, :tipo, :cantidad, :zona, :prioridad]
  defstruct [
    :id,
    :tipo,
    :descripcion,
    :cantidad,
    :zona,
    :prioridad,
    :reportado_por,
    :creada_en,
    cantidad_asignada: 0,
    estado: :pendiente,
    asignaciones: []
  ]

  @type t :: %__MODULE__{}

  def prioridades, do: @prioridades

  @doc "Peso numérico de una prioridad (menor = más urgente)."
  def peso(:critica), do: 0
  def peso(:alta), do: 1
  def peso(:media), do: 2
  def peso(:baja), do: 3

  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(_datos), do: {:error, :no_implementado}

  @doc "Cambia el estado validando la transición (Estados.transicion/3)."
  @spec cambiar_estado(t(), atom()) :: {:ok, t()} | {:error, atom()}
  def cambiar_estado(_necesidad, _nuevo), do: {:error, :no_implementado}

  @doc "Registra una asignación de recurso. Rechaza necesidades atendidas/canceladas."
  @spec registrar_asignacion(t(), {String.t(), String.t(), pos_integer()}) ::
          {:ok, t()} | {:error, atom()}
  def registrar_asignacion(_necesidad, _asignacion), do: {:error, :no_implementado}

  @doc "Cantidad que aún falta cubrir."
  @spec faltante(t()) :: non_neg_integer()
  def faltante(%__MODULE__{cantidad: c, cantidad_asignada: a}), do: max(c - a, 0)

  # --- RECURSIVAS (TODO) ---

  @doc "Inserta en una lista ya ordenada respetando prioridad (recursivo)."
  @spec insertar_por_prioridad([t()], t()) :: [t()]
  def insertar_por_prioridad(lista, _necesidad), do: lista

  @doc "Ordena por prioridad usando `insertar_por_prioridad/2` (recursivo)."
  @spec ordenar([t()]) :: [t()]
  def ordenar(necesidades), do: necesidades

  @doc "Filtra por zona, tipo, prioridad y/o estado. `filtros` es una keyword list."
  @spec filtrar([t()], keyword()) :: [t()]
  def filtrar(necesidades, _filtros), do: necesidades
end
