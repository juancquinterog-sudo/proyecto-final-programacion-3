defmodule Emergencias.Dominio.Persona do
  @moduledoc """
  Persona afectada (req. 1.4.6). Conserva el HISTORIAL de cambios de estado como
  lista de tuplas `{estado, fecha, usuario}` (el más reciente primero).

  Estados: `:sin_informacion | :reportada | :localizada | :trasladada |
  :en_albergue | :reunificada`.
  """

  @enforce_keys [:documento, :nombre, :zona, :estado]
  defstruct [:id, :documento, :nombre, :edad, :zona, :estado, :albergue, historial: []]

  @type t :: %__MODULE__{}

  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(_datos), do: {:error, :no_implementado}

  @spec cambiar_estado(t(), atom(), String.t()) :: {:ok, t()} | {:error, atom()}
  def cambiar_estado(_persona, _nuevo, _usuario), do: {:error, :no_implementado}

  @doc "Búsqueda por nombre (contiene), documento, zona o estado. `filtros` = keyword."
  @spec buscar([t()], keyword()) :: [t()]
  def buscar(personas, _filtros), do: personas
end
