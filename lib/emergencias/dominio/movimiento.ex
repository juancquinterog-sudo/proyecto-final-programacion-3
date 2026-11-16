defmodule Emergencias.Dominio.Movimiento do
  @moduledoc """
  Movimiento de inventario (entrada, salida, asignación, transferencia).
  El historial de movimientos se conserva siempre (req. 1.4.5).
  """

  @enforce_keys [:codigo_recurso, :tipo, :cantidad, :ubicacion]
  defstruct [:codigo_recurso, :tipo, :cantidad, :ubicacion, :referencia, :usuario, :fecha]

  @type tipo :: :entrada | :salida | :asignacion | :transferencia_salida | :transferencia_entrada
  @type t :: %__MODULE__{
          codigo_recurso: String.t(),
          tipo: tipo(),
          cantidad: pos_integer(),
          ubicacion: String.t(),
          referencia: String.t() | nil,
          usuario: String.t() | nil,
          fecha: DateTime.t() | nil
        }
end
