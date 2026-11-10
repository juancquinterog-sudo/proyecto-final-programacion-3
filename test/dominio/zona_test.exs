defmodule Emergencias.Dominio.ZonaTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{PuntoAtencion, Sector, Zona}

  # zona 10 + s1 (20 + p1 5 + p2 3) + s2 (7 + p3 1) = 46
  defp arbol do
    %Zona{
      codigo: "centro",
      nombre: "Centro",
      nivel: :critico,
      personas_estimadas: 10,
      sectores: [
        %Sector{
          codigo: "s1",
          nombre: "Sector 1",
          nivel: :alto,
          personas_estimadas: 20,
          puntos: [
            %PuntoAtencion{codigo: "p1", nombre: "P1", personas_estimadas: 5},
            %PuntoAtencion{codigo: "p2", nombre: "P2", personas_estimadas: 3}
          ]
        },
        %Sector{
          codigo: "s2",
          nombre: "Sector 2",
          nivel: :medio,
          personas_estimadas: 7,
          puntos: [%PuntoAtencion{codigo: "p3", nombre: "P3", personas_estimadas: 1}]
        }
      ]
    }
  end

  describe "nueva/1" do
    test "crea una zona válida" do
      assert {:ok, %Zona{codigo: "norte", nivel: :alto, personas_estimadas: 0, sectores: []}} =
               Zona.nueva(%{codigo: "norte", nombre: "Norte", nivel: "alto"})

      assert {:ok, %Zona{personas_estimadas: 300}} =
               Zona.nueva(%{codigo: "n", nombre: "N", nivel: :bajo, personas_estimadas: "300"})
    end

    test "valida los datos" do
      assert Zona.nueva(%{codigo: "", nombre: "N", nivel: :alto}) == {:error, :texto_vacio}
      assert Zona.nueva(%{codigo: "n", nombre: "N", nivel: "gigante"}) == {:error, :nivel_invalido}
      assert Zona.nueva(%{codigo: "n", nombre: "N"}) == {:error, :nivel_invalido}

      assert Zona.nueva(%{codigo: "n", nombre: "N", nivel: :alto, personas_estimadas: -5}) ==
               {:error, :cantidad_invalida}
    end
  end

  describe "agregar_sector/2 y agregar_punto/3" do
    test "agrega sectores y puntos" do
      {:ok, zona} = Zona.nueva(%{codigo: "z", nombre: "Z", nivel: :medio})
      {:ok, sector} = Sector.nuevo(%{codigo: "s1", nombre: "S1"})
      {:ok, punto} = PuntoAtencion.nuevo(%{codigo: "p1", nombre: "P1", personas_estimadas: 4})

      assert {:ok, zona} = Zona.agregar_sector(zona, sector)
      assert {:ok, zona} = Zona.agregar_punto(zona, "s1", punto)
      assert Zona.contar_puntos(zona) == 1
      assert Zona.total_afectados(zona) == 4
    end

    test "rechaza sector duplicado, punto duplicado y sector inexistente" do
      zona = arbol()
      sector = %Sector{codigo: "s1", nombre: "otro"}
      assert Zona.agregar_sector(zona, sector) == {:error, :sector_duplicado}

      punto = %PuntoAtencion{codigo: "p3", nombre: "repetido"}
      assert Zona.agregar_punto(zona, "s1", punto) == {:error, :punto_duplicado}

      nuevo = %PuntoAtencion{codigo: "p9", nombre: "nuevo"}
      assert Zona.agregar_punto(zona, "no_existe", nuevo) == {:error, :sector_no_existe}
    end
  end

  describe "recursivas sobre el árbol" do
    test "total_afectados suma zona, sectores y puntos" do
      assert Zona.total_afectados(arbol()) == 46
    end

    test "total_afectados sobre un sector, un punto y listas" do
      [s1, s2] = arbol().sectores
      assert Zona.total_afectados(s1) == 28
      assert Zona.total_afectados(s2) == 8
      assert Zona.total_afectados(hd(s1.puntos)) == 5
      assert Zona.total_afectados([]) == 0
      assert Zona.total_afectados([s1, s2]) == 36
    end

    test "zona sin sectores" do
      assert Zona.total_afectados(%Zona{codigo: "z", nombre: "Z", nivel: :bajo, personas_estimadas: 3}) == 3
    end

    test "contar_puntos recorre todo el árbol" do
      assert Zona.contar_puntos(arbol()) == 3
      assert Zona.contar_puntos(%Zona{codigo: "z", nombre: "Z", nivel: :bajo}) == 0
    end

    test "buscar_punto encuentra un punto en cualquier sector" do
      assert {:ok, %PuntoAtencion{codigo: "p1"}} = Zona.buscar_punto(arbol(), "p1")
      assert {:ok, %PuntoAtencion{codigo: "p3", personas_estimadas: 1}} = Zona.buscar_punto(arbol(), "p3")
    end

    test "buscar_punto retorna error si no existe" do
      assert Zona.buscar_punto(arbol(), "zzz") == {:error, :no_encontrado}
      assert Zona.buscar_punto([], "p1") == {:error, :no_encontrado}
    end

    test "estadisticas acumula la zona y sus sectores" do
      assert Zona.estadisticas(arbol()) == %{
               codigo: "centro",
               nivel: :critico,
               total_afectados: 46,
               sectores: 2,
               puntos: 3,
               por_nivel: %{alto: 1, medio: 1},
               afectados_por_sector: [{"s1", 28}, {"s2", 8}]
             }
    end
  end

  describe "cambios" do
    test "cambiar_nivel y actualizar_personas" do
      zona = arbol()
      assert {:ok, %Zona{nivel: :bajo}} = Zona.cambiar_nivel(zona, "bajo")
      assert Zona.cambiar_nivel(zona, "x") == {:error, :nivel_invalido}
      assert {:ok, %Zona{personas_estimadas: 99}} = Zona.actualizar_personas(zona, 99)
      assert Zona.actualizar_personas(zona, -1) == {:error, :cantidad_invalida}
    end
  end
end
