defmodule Emergencias.Servicios.AsignadorTest do
  use ExUnit.Case, async: false

  alias Emergencias.Servicios.Asignador
  alias Emergencias.Servidores.{NecesidadServer, RecursoServer}
  alias Emergencias.Dominio.{Recurso, Necesidad}

  test "asigna de varios recursos con tomar_de_recursos" do
    r1 = %Recurso{codigo: "R_T1", nombre: "agua", categoria: "agua", existencias: %{"centro_1" => 15}, unidad: "litros"}
    r2 = %Recurso{codigo: "R_T2", nombre: "agua", categoria: "agua", existencias: %{"centro_2" => 20}, unidad: "litros"}

    RecursoServer.registrar(r1)
    RecursoServer.registrar(r2)

    # Creamos la struct y usamos registrar/1 como lo define el servidor
    need_struct = %Necesidad{id: "N_TEST_1", tipo: :agua, cantidad: 30, prioridad: :critica, zona: "centro", descripcion: "Punto 1", estado: :pendiente}
    {:ok, need} = NecesidadServer.registrar(need_struct)

    assert {:ok, %{necesidad: id, tomado: tomado}} =
             Asignador.asignar(need.id, "agua", 30, "laura")

    assert id == need.id
    assert length(tomado) == 2
  end

  test "rollback si falla el registro en la necesidad" do
    r_rb = %Recurso{codigo: "R_RB", nombre: "agua", categoria: "agua", existencias: %{"centro_1" => 40}, unidad: "litros"}
    RecursoServer.registrar(r_rb)

    assert {:error, _razon} = Asignador.asignar("NEED_INEXISTENTE", "agua", 20, "laura")
  end

  test "dos asignaciones simultáneas (escenario del PDF)" do
    r001 = %Recurso{codigo: "R001", nombre: "agua", categoria: "agua", existencias: %{"centro_acopio_1" => 50}, unidad: "litros"}
    RecursoServer.registrar(r001)

    n1_struct = %Necesidad{id: "N_PDF_1", tipo: :agua, cantidad: 30, prioridad: :critica, zona: "centro", descripcion: "Sector 1", estado: :pendiente}
    n2_struct = %Necesidad{id: "N_PDF_2", tipo: :agua, cantidad: 25, prioridad: :critica, zona: "centro", descripcion: "Sector 2", estado: :pendiente}

    {:ok, n1} = NecesidadServer.registrar(n1_struct)
    {:ok, n2} = NecesidadServer.registrar(n2_struct)

    t1 = Task.async(fn -> Asignador.asignar(n1.id, "agua", 30, "laura") end)
    t2 = Task.async(fn -> Asignador.asignar(n2.id, "agua", 25, "carlos") end)

    resultados = [Task.await(t1), Task.await(t2)]

    exitos = Enum.count(resultados, &match?({:ok, _}, &1))

    assert exitos >= 1
  end
end
