defmodule Emergencias.Dominio.SimilitudEstadisticasTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{Albergue, Estadisticas, Mascota, Recurso, Similitud}

  defp m(id, tipo, attrs \\ %{}) do
    base = %{
      id: id,
      tipo: tipo,
      especie: "perro",
      zona: "z1",
      color: "negro",
      tamano: :mediana,
      nombre: nil,
      caracteristicas: MapSet.new(["collar"])
    }

    {:ok, mascota} = Mascota.nuevo(Map.merge(base, attrs))
    mascota
  end

  describe "Similitud" do
    test "puntaje máximo, descarte por especie o tipo, y parciales" do
      p = m("M1", :perdida, %{nombre: "Luna"})
      assert Similitud.puntaje(p, m("M2", :encontrada, %{nombre: "Luna"})) == 1.0
      assert Similitud.puntaje(p, m("M2", :encontrada, %{especie: "gato"})) == 0.0
      assert Similitud.puntaje(p, m("M3", :perdida)) == 0.0
      assert Similitud.puntaje(p, m("M2", :encontrada, %{tamano: :pequena, zona: "z2"})) < 1.0
      pequena = m("M5", :perdida, %{tamano: :pequena})

      assert Similitud.puntaje(pequena, m("M6", :encontrada, %{tamano: :grande})) <
               Similitud.puntaje(pequena, m("M6", :encontrada, %{tamano: :mediana}))
    end

    test "jaccard" do
      assert Similitud.jaccard(MapSet.new(), MapSet.new()) == 0.0
      assert Similitud.jaccard(MapSet.new([1, 2]), MapSet.new([2, 3])) == 1 / 3
    end

    test "buscar_coincidencias ordena por puntaje y excluye resueltas" do
      p = m("M1", :perdida)
      buena = m("M2", :encontrada)
      mala = m("M3", :encontrada, %{zona: "z9", color: "blanco", caracteristicas: MapSet.new()})
      resuelta = m("M4", :encontrada, %{estado: :resuelta})
      assert [{^p, ^buena, _}] = Similitud.buscar_coincidencias([p, mala, buena, resuelta])
    end
  end

  describe "Estadisticas (recursivas)" do
    test "sumar, contar_si y agrupar" do
      assert Estadisticas.sumar([]) == 0
      assert Estadisticas.sumar([1, 2, 3]) == 6
      assert Estadisticas.contar_si([1, 2, 3, 4], &(rem(&1, 2) == 0)) == 2
      assert Estadisticas.agrupar([1, 2, 3, 4, 5], &rem(&1, 2)) == %{0 => [2, 4], 1 => [1, 3, 5]}
      assert Estadisticas.agrupar([], & &1) == %{}
    end

    test "albergues más ocupados y recursos críticos" do
      {:ok, a1} = Albergue.nuevo(%{codigo: "A1", nombre: "a", zona: "z", capacidad: 10})
      {:ok, a2} = Albergue.nuevo(%{codigo: "A2", nombre: "b", zona: "z", capacidad: 2})
      {:ok, a2} = Albergue.ingresar(a2, "1")
      {:ok, a1} = Albergue.ingresar(a1, "1")
      assert [%{codigo: "A2"}, %{codigo: "A1"}] = Estadisticas.albergues_mas_ocupados([a1, a2], 5)
      assert [%{codigo: "A2"}] = Estadisticas.albergues_mas_ocupados([a1, a2], 1)

      {:ok, poco} =
        Recurso.nuevo(%{
          codigo: "R1",
          nombre: "x",
          categoria: "agua",
          unidad: "l",
          cantidad: 5,
          ubicacion: "u"
        })

      {:ok, mucho} =
        Recurso.nuevo(%{
          codigo: "R2",
          nombre: "x",
          categoria: "agua",
          unidad: "l",
          cantidad: 500,
          ubicacion: "u"
        })

      assert [%{codigo: "R1"}] = Estadisticas.recursos_criticos([mucho, poco], 20)
    end
  end
end
