defmodule Emergencias.Dominio.SectorPuntoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{PuntoAtencion, Sector}

  test "Sector.nuevo usa nivel :medio por defecto" do
    assert {:ok, %Sector{nivel: :medio, personas_estimadas: 0, puntos: []}} =
             Sector.nuevo(%{codigo: "s1", nombre: "Sector 1"})
  end

  test "Sector.nuevo valida" do
    assert Sector.nuevo(%{codigo: "", nombre: "x"}) == {:error, :texto_vacio}
    assert Sector.nuevo(%{codigo: "s", nombre: "x", nivel: "enorme"}) == {:error, :nivel_invalido}
    assert Sector.nuevo(%{codigo: "s", nombre: "x", personas_estimadas: -2}) == {:error, :cantidad_invalida}
  end

  test "PuntoAtencion.nuevo" do
    assert {:ok, %PuntoAtencion{codigo: "p1", personas_estimadas: 12}} =
             PuntoAtencion.nuevo(%{codigo: "p1", nombre: "Punto", personas_estimadas: "12"})

    assert PuntoAtencion.nuevo(%{codigo: "p1", nombre: ""}) == {:error, :texto_vacio}
    assert PuntoAtencion.nuevo(%{codigo: "p1", nombre: "P", personas_estimadas: -1}) == {:error, :cantidad_invalida}
  end
end
