defmodule Emergencias.Dominio.EstadosTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Estados

  test "transiciones válidas de necesidad" do
    assert Estados.transicion(:necesidad, :pendiente, :asignada) == {:ok, :asignada}
    assert Estados.transicion(:necesidad, :asignada, :en_atencion) == {:ok, :en_atencion}
    assert Estados.transicion(:necesidad, :en_atencion, :atendida) == {:ok, :atendida}
    assert Estados.transicion(:necesidad, :pendiente, :cancelada) == {:ok, :cancelada}
  end

  test "transiciones inválidas retornan error" do
    assert Estados.transicion(:necesidad, :pendiente, :atendida) == {:error, :transicion_invalida}
    assert Estados.transicion(:necesidad, :atendida, :cancelada) == {:error, :transicion_invalida}
    assert Estados.transicion(:necesidad, :cancelada, :pendiente) == {:error, :transicion_invalida}
    assert Estados.transicion(:necesidad, :inexistente, :asignada) == {:error, :transicion_invalida}
  end

  test "no se puede cerrar dos veces (estado terminal)" do
    assert Estados.terminal?(:necesidad, :atendida)
    assert Estados.terminal?(:necesidad, :cancelada)
    assert Estados.terminal?(:mascota, :resuelta)
    assert Estados.terminal?(:persona, :reunificada)
    refute Estados.terminal?(:necesidad, :pendiente)
  end

  test "persona: flujo del enunciado y retrocesos no permitidos" do
    assert Estados.transicion(:persona, :sin_informacion, :localizada) == {:ok, :localizada}
    assert Estados.transicion(:persona, :localizada, :en_albergue) == {:ok, :en_albergue}
    assert Estados.transicion(:persona, :reunificada, :localizada) == {:error, :transicion_invalida}
  end

  test "mascota y mensaje" do
    assert Estados.transicion(:mascota, :activa, :posible_coincidencia) == {:ok, :posible_coincidencia}
    assert Estados.transicion(:mascota, :resuelta, :activa) == {:error, :transicion_invalida}
    assert Estados.transicion(:mensaje, :pendiente, :entregado) == {:ok, :entregado}
  end

  test "estados/1 lista los estados de una entidad" do
    assert Enum.sort(Estados.estados(:necesidad)) ==
             Enum.sort([:pendiente, :asignada, :en_atencion, :atendida, :cancelada])
  end
end
