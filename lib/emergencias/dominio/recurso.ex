defmodule Emergencias.Dominio.Recurso do
  @moduledoc """
  Recurso e inventario (req. 1.4.5). Módulo puro: cada función recibe un
  `Recurso` y devuelve otro NUEVO (inmutabilidad). La exclusión mutua real la
  da `Servidores.RecursoServer` (un proceso por recurso).

  El inventario se guarda por ubicación en un mapa: `existencias: %{"centro_acopio_1" => 50}`.
  Así una transferencia entre centros es una operación atómica dentro de UN
  solo proceso (no hay riesgo de que otro proceso vea "50 menos aquí, 0 allá").
  """

  alias Emergencias.Dominio.Movimiento

  @enforce_keys [:codigo, :nombre, :categoria, :unidad]
  defstruct [:codigo, :nombre, :categoria, :unidad, :zona, existencias: %{}, historial: []]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          categoria: atom(),
          unidad: String.t(),
          zona: String.t() | nil,
          existencias: %{String.t() => non_neg_integer()},
          historial: [Movimiento.t()]
        }

  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(_datos), do: {:error, :no_implementado}

  @spec disponible(t(), String.t()) :: non_neg_integer()
  def disponible(%__MODULE__{existencias: e}, ubicacion), do: Map.get(e, ubicacion, 0)

  @spec total(t()) :: non_neg_integer()
  def total(%__MODULE__{existencias: e}), do: e |> Map.values() |> Enum.sum()

  @spec entrada(t(), String.t(), pos_integer(), map()) :: {:ok, t()} | {:error, atom()}
  def entrada(_recurso, _ubicacion, _cantidad, _meta), do: {:error, :no_implementado}

  @spec salida(t(), String.t(), pos_integer(), map()) ::
          {:ok, t()} | {:error, :stock_insuficiente | atom()}
  def salida(_recurso, _ubicacion, _cantidad, _meta), do: {:error, :no_implementado}

  @spec transferir(t(), String.t(), String.t(), pos_integer(), map()) ::
          {:ok, t()} | {:error, atom()}
  def transferir(_recurso, _origen, _destino, _cantidad, _meta), do: {:error, :no_implementado}
end
