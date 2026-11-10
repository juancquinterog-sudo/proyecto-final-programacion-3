defmodule Emergencias.Dominio.Sector do
  @moduledoc "Sector dentro de una zona. Contiene puntos de atención (nivel intermedio del árbol)."
  alias Emergencias.Dominio.PuntoAtencion

  @enforce_keys [:codigo, :nombre]
  defstruct [:codigo, :nombre, nivel: :medio, personas_estimadas: 0, puntos: []]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          nivel: :critico | :alto | :medio | :bajo,
          personas_estimadas: non_neg_integer(),
          puntos: [PuntoAtencion.t()]
        }
end
