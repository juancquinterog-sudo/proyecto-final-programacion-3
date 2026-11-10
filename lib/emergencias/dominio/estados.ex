defmodule Emergencias.Dominio.Estados do
  @moduledoc """
  Máquinas de estado de las entidades (req. 1.4.9: "transiciones válidas").
  Los grafos son DATOS (mapas de listas), por eso la validación es una función
  pura de una línea y fácil de probar.
  """

  @necesidad %{
    pendiente: [:asignada, :cancelada],
    asignada: [:en_atencion, :cancelada],
    en_atencion: [:atendida, :cancelada],
    atendida: [],
    cancelada: []
  }

  @persona %{
    sin_informacion: [:reportada, :localizada],
    reportada: [:localizada],
    localizada: [:trasladada, :en_albergue, :reunificada],
    trasladada: [:en_albergue, :reunificada],
    en_albergue: [:trasladada, :reunificada],
    reunificada: []
  }

  @mascota %{
    activa: [:posible_coincidencia, :resuelta],
    posible_coincidencia: [:activa, :resuelta],
    resuelta: []
  }

  @mensaje %{
    pendiente: [:entregado],
    entregado: [:pendiente]
  }

  @grafos %{necesidad: @necesidad, persona: @persona, mascota: @mascota, mensaje: @mensaje}

  @doc "Estados posibles de una entidad."
  def estados(entidad), do: @grafos |> Map.fetch!(entidad) |> Map.keys()

  @doc "Valida una transición. `{:ok, nuevo} | {:error, :transicion_invalida}`."
  @spec transicion(atom(), atom(), atom()) :: {:ok, atom()} | {:error, :transicion_invalida}
  def transicion(entidad, actual, nuevo) do
    case @grafos |> Map.fetch!(entidad) |> Map.get(actual) do
      nil -> {:error, :transicion_invalida}
      permitidos -> if nuevo in permitidos, do: {:ok, nuevo}, else: {:error, :transicion_invalida}
    end
  end

  @doc "Un estado terminal no admite más cambios (ej. no cerrar dos veces)."
  def terminal?(entidad, estado), do: Map.get(@grafos[entidad], estado) == []
end
