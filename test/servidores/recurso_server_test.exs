defmodule Emergencias.Servidores.RecursoServerTest do
  use ExUnit.Case, async: true

  # Pruebas pendientes: quitar @moduletag :skip al implementar el módulo.
  @moduletag :skip

  test "CONCURRENCIA: 30 + 25 sobre 50 nunca supera el inventario" do
    flunk("pendiente")
  end

  test "100 reservas simultáneas de 1 unidad sobre stock 50 -> exactamente 50 éxitos" do
    flunk("pendiente")
  end

  test "transferencia concurrente conserva el total" do
    flunk("pendiente")
  end
end
