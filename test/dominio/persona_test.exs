defmodule Emergencias.Dominio.PersonaTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Persona

  test "crear struct de persona" do
    persona = %Persona{
      id: "12345",
      nombre: "Juan",
      documento: "1090123456",
      zona: "Z01",
      estado: :activo
    }
    assert persona.nombre == "Juan"
  end
end
