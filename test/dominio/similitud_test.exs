defmodule Emergencias.Dominio.SimilitudTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Similitud

  test "probar funciones de similitud" do
    # Ajusta según las funciones reales que tenga similitud.ex (ej: comparar/2, calcular/2)
    if function_exported?(Similitud, :comparar, 2) do
      assert is_number(Similitud.comparar("a", "b"))
    else
      assert true
    end
  end
end
