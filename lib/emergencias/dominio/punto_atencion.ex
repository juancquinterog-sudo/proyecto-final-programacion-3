defmodule Emergencias.Dominio.PuntoAtencion do
  @moduledoc "Punto de atención (hoja del árbol zona -> sector -> punto)."

  @enforce_keys [:codigo, :nombre]
  defstruct [:codigo, :nombre, personas_estimadas: 0]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          personas_estimadas: non_neg_integer()
        }
end
