defmodule Emergencias.Dominio.CoberturaExtraTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{Persona, Mascota, Mensaje, Estadisticas, Similitud}

  test "ejecutar funciones completas de todo el dominio" do
    # 1. Persona
    assert {:ok, p1} = Persona.nueva(%{documento: "123", nombre: "Juan Perez", zona: "Z1", estado: :sin_informacion})
    assert {:ok, p2} = Persona.nueva(%{documento: "456", nombre: "Maria Gomez", zona: "Z2", estado: :reportada})
    assert {:ok, p1_act} = Persona.cambiar_estado(p1, :localizada, "admin")
    assert [_ | _] = Persona.buscar([p1_act, p2], nombre: "Juan")
    assert [_ | _] = Persona.buscar([p1_act, p2], documento: "456")
    assert [_ | _] = Persona.buscar([p1_act, p2], zona: "Z1")
    assert [_ | _] = Persona.buscar([p1_act, p2], estado: :reportada)
    assert [] = Persona.buscar([p1_act, p2], zona: "Z99")

    # 2. Mascota
    assert {:ok, m1} = Mascota.nuevo(%{id: "M1", tipo: :perdida, especie: :perro, zona: "Z1", estado: :activa})
    assert {:ok, m2} = Mascota.nuevo(%{id: "M2", tipo: :encontrada, especie: :perro, zona: "Z1", estado: :activa})
    assert {:ok, _m1_act} = Mascota.cambiar_estado(m1, :posible_coincidencia)
    assert {:ok, {_res1, _res2}} = Mascota.confirmar_coincidencia(m1, m2)

    # 3. Mensaje
    assert {:ok, msg} = Mensaje.nuevo(%{id: "MSG1", destinatario: "P1", remitente: "P2", contenido: "Ayuda"})
    assert {:ok, _msg_marcado} = Mensaje.marcar(msg, :entregado)

    # 4. Estadisticas y Similitud (verificamos su existencia y carga)
    assert Code.ensure_loaded?(Estadisticas)
    assert Code.ensure_loaded?(Similitud)
  end
end
