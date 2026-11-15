defmodule Emergencias.Dominio.MascotaDomTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Mascota

  test "crear struct de mascota" do
    m = %Mascota{
      id: "M01",
      nombre: "Firulais",
      especie: :perro,
      tipo: :perro,
      estado: :rescate,
      zona: "Z01"
    }
    assert m.id == "M01"
    assert m.nombre == "Firulais"
  end
end
