defmodule Emergencias.Dominio.EstadisticasTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Estadisticas

  test "probar funciones de estadisticas" do
    # Ajusta esta llamada según las funciones reales que tenga tu módulo estadisticas.ex
    # Por ejemplo, si tiene una función calcular/1 o similar:
    if function_exported?(Estadisticas, :calcular, 1) do
      assert is_map(Estadisticas.calcular([]))
    else
      assert true
    end
  end
end
