defmodule Emergencias.Persistencia.CodecTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{
    Albergue,
    Mascota,
    Mensaje,
    Movimiento,
    Necesidad,
    Persona,
    PuntoAtencion,
    Recurso,
    Sector,
    Usuario,
    Zona
  }

  alias Emergencias.Persistencia.Codec

  @fecha ~U[2026-11-10 01:00:00Z]
  @raro "a|b;c:d\\e\nf"

  defp ida_y_vuelta(entidad, registro) do
    [linea] = Codec.a_lineas(registro)
    refute String.contains?(linea, "\n")
    Codec.de_linea(entidad, linea)
  end

  describe "escapar/desescapar/dividir" do
    test "escapar y desescapar son inversas" do
      assert @raro |> Codec.escapar() |> Codec.desescapar() == @raro
      assert "ñandú ✓" |> Codec.escapar() |> Codec.desescapar() == "ñandú ✓"
    end

    test "el texto escapado no contiene separadores sin escapar" do
      assert [_unico] = @raro |> Codec.escapar() |> Codec.dividir("|")
      assert [_unico] = @raro |> Codec.escapar() |> Codec.dividir(";")
      assert [_unico] = @raro |> Codec.escapar() |> Codec.dividir(":")
    end

    test "dividir parte por el separador y respeta los escapados" do
      assert Codec.dividir("a|b|c") == ["a", "b", "c"]
      assert Codec.dividir("a||c") == ["a", "", "c"]
      assert Codec.dividir("a\\|b|c") == ["a\\|b", "c"]
      assert Codec.dividir("x;y", ";") == ["x", "y"]
      assert Codec.dividir("") == [""]
    end
  end

  describe "ida y vuelta por entidad" do
    test "usuario" do
      u = %Usuario{
        nombre_usuario: "laura",
        hash_contrasena: "abc",
        nombre_completo: @raro,
        tipo: :coordinador,
        zona: "centro"
      }

      assert ida_y_vuelta(:usuarios, u) == {:ok, u}
    end

    test "usuario con campos opcionales vacíos" do
      u = %Usuario{
        nombre_usuario: "ana",
        hash_contrasena: "abc",
        nombre_completo: nil,
        tipo: :ciudadano,
        zona: nil
      }

      assert ida_y_vuelta(:usuarios, u) == {:ok, u}
    end

    test "necesidad con asignaciones" do
      n = %Necesidad{
        id: "N001",
        tipo: :agua,
        descripcion: "Punto de atención | sector 3",
        cantidad: 30,
        cantidad_asignada: 30,
        zona: "centro",
        prioridad: :critica,
        reportado_por: "laura",
        creada_en: @fecha,
        estado: :asignada,
        asignaciones: [{"R001", "centro_acopio_1", 20}, {"R002", "bodega:2", 10}]
      }

      assert ida_y_vuelta(:necesidades, n) == {:ok, n}
    end

    test "necesidad sin asignaciones" do
      n = %Necesidad{id: "N002", tipo: :agua, cantidad: 5, zona: "z", prioridad: :baja}
      assert ida_y_vuelta(:necesidades, n) == {:ok, n}
    end

    test "recurso (el historial va en movimientos.txt)" do
      r = %Recurso{
        codigo: "R001",
        nombre: "Agua",
        categoria: :agua,
        unidad: "litros",
        zona: "centro",
        existencias: %{"centro_acopio_1" => 50, "albergue_2" => 0}
      }

      assert ida_y_vuelta(:recursos, r) == {:ok, r}
    end

    test "movimiento" do
      m = %Movimiento{
        codigo_recurso: "R001",
        tipo: :asignacion,
        cantidad: 30,
        ubicacion: "centro_acopio_1",
        referencia: "N001",
        usuario: "laura",
        fecha: @fecha
      }

      assert ida_y_vuelta(:movimientos, m) == {:ok, m}
    end

    test "persona con historial" do
      p = %Persona{
        id: "P1",
        documento: "123",
        nombre: "Andrés",
        edad: 30,
        zona: "norte",
        estado: :en_albergue,
        albergue: "A01",
        historial: [{:en_albergue, @fecha, "laura"}, {:localizada, @fecha, "ana"}]
      }

      assert ida_y_vuelta(:personas, p) == {:ok, p}
    end

    test "persona sin edad ni historial" do
      p = %Persona{documento: "9", nombre: "X", zona: "z", estado: :reportada}
      assert ida_y_vuelta(:personas, p) == {:ok, p}
    end

    test "mensaje" do
      m = %Mensaje{
        id: "M1",
        destinatario: "123",
        remitente: "familiar",
        contenido: "Estoy bien, estoy en el albergue norte",
        fecha: @fecha,
        estado: :pendiente
      }

      assert ida_y_vuelta(:mensajes, m) == {:ok, m}
    end

    test "mascota" do
      m = %Mascota{
        id: "MA1",
        tipo: :perdida,
        especie: "perro",
        nombre: "Luna",
        color: "negra",
        tamano: :mediana,
        zona: "norte",
        contacto: "3001234567",
        caracteristicas: MapSet.new(["collar rojo", "cola corta"]),
        estado: :activa
      }

      assert ida_y_vuelta(:mascotas, m) == {:ok, m}
    end

    test "albergue" do
      a = %Albergue{
        codigo: "A01",
        nombre: "Albergue Norte",
        zona: "norte",
        capacidad: 150,
        ocupantes: MapSet.new(["123", "456"])
      }

      assert ida_y_vuelta(:albergues, a) == {:ok, a}
    end
  end

  describe "zonas (varias líneas)" do
    test "se reconstruye el árbol zona -> sectores -> puntos" do
      zona = %Zona{
        codigo: "centro",
        nombre: "Centro",
        nivel: :critico,
        personas_estimadas: 1000,
        sectores: [
          %Sector{
            codigo: "s1",
            nombre: "Sector 1",
            nivel: :alto,
            personas_estimadas: 400,
            puntos: [
              %PuntoAtencion{codigo: "p1", nombre: "Punto 1", personas_estimadas: 100},
              %PuntoAtencion{codigo: "p2", nombre: "Punto 2", personas_estimadas: 50}
            ]
          },
          %Sector{
            codigo: "s2",
            nombre: "Sector 2",
            nivel: :medio,
            personas_estimadas: 200,
            puntos: []
          }
        ]
      }

      otra = %Zona{codigo: "norte", nombre: "Norte", nivel: :bajo, personas_estimadas: 5}
      lineas = Enum.flat_map([zona, otra], &Codec.a_lineas/1)
      assert length(lineas) == 1 + 2 + 2 + 1
      assert Codec.de_lineas(:zonas, lineas) == {:ok, [zona, otra]}
    end
  end

  describe "líneas inválidas" do
    test "campos de menos o números mal formados" do
      assert Codec.de_linea(:usuarios, "solo|dos") == {:error, :linea_invalida}
      assert Codec.de_linea(:albergues, "A|B|C|no_numero|") == {:error, :linea_invalida}
      assert Codec.de_linea(:desconocida, "x") == {:error, :linea_invalida}
    end

    test "de_lineas reporta la línea mala" do
      assert Codec.de_lineas(:usuarios, ["x"]) == {:error, {:linea_invalida, "x"}}
    end
  end
end
