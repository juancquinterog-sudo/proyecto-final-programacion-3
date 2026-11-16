defmodule Emergencias.Cli.ZonasNecesidadesTest do
  use ExUnit.Case, async: false

  alias Emergencias.Cli.{Comandos, Parser, Sesion}

  defp unico, do: System.unique_integer([:positive])

  defp conectar(tipo) do
    {:ok, sesion, _} =
      Comandos.ejecutar(Sesion.anonima(), {:connect, ["u#{unico()}", "1234", tipo, "centro"], []})

    sesion
  end

  # Ejecuta una línea de texto como lo haría la consola.
  defp cmd(sesion, linea) do
    {:ok, comando} = Parser.parsear(linea)
    Comandos.ejecutar(sesion, comando)
  end

  defp posicion(texto, buscado) do
    {pos, _} = :binary.match(texto, buscado)
    pos
  end

  describe "zonas" do
    test "register_zone, register_sector, register_point y zone_status" do
      coord = conectar("coordinador")
      z = "z#{unico()}"

      assert {:ok, _, msg} = cmd(coord, "register_zone #{z} Centro critico 100")
      assert msg =~ "registrada"
      assert {:ok, _, _} = cmd(coord, "register_sector #{z} s1 \"Sector uno\" alto 40")
      assert {:ok, _, _} = cmd(coord, "register_sector #{z} s2 Sector2")
      assert {:ok, _, msg} = cmd(coord, "register_point #{z} s1 p1 \"Punto 1\" 10")
      assert msg =~ "p1"

      assert {:ok, _, estado} = cmd(coord, "zone_status #{z}")
      assert estado =~ "Zona #{z} - Centro (nivel critico)"
      assert estado =~ "Personas afectadas (total): 150"
      assert estado =~ "Sectores: 2 | Puntos de atención: 1"
      assert estado =~ "Sector uno"
    end

    test "list_zones muestra las zonas con sus totales" do
      coord = conectar("coordinador")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_zone #{z} Norte bajo 5")
      assert {:ok, _, tabla} = cmd(coord, "list_zones")
      assert tabla =~ z
      assert tabla =~ "afectados"
    end

    test "errores: duplicados, niveles, zona inexistente y uso" do
      coord = conectar("coordinador")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_zone #{z} Centro alto")
      assert cmd(coord, "register_zone #{z} Otra bajo") == {:error, :id_duplicado}
      assert cmd(coord, "register_zone x#{z} Otra gigante") == {:error, :nivel_invalido}
      assert cmd(coord, "register_sector no_existe_#{z} s1 S") == {:error, :no_existe}
      assert cmd(coord, "zone_status no_existe_#{z}") == {:error, :no_existe}
      assert {:error, {:uso, _}} = cmd(coord, "register_zone solo_codigo")
      assert {:error, {:uso, _}} = cmd(coord, "zone_status")
    end

    test "un ciudadano consulta pero no registra" do
      coord = conectar("coordinador")
      ciudadano = conectar("ciudadano")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_zone #{z} Centro alto")

      assert cmd(ciudadano, "register_zone otra Otra alto") == {:error, :sin_permiso}
      assert cmd(ciudadano, "register_sector #{z} s1 S") == {:error, :sin_permiso}
      assert {:ok, _, _} = cmd(ciudadano, "zone_status #{z}")
      assert {:ok, _, _} = cmd(ciudadano, "list_zones")
    end
  end

  describe "necesidades" do
    test "register_need y list_needs" do
      coord = conectar("coordinador")
      z = "z#{unico()}"

      assert {:ok, _, msg} =
               cmd(coord, "register_need agua 30 critica #{z} \"Punto de atención sector 3\"")

      assert msg =~ ~r/Necesidad N\d+ registrada: 30 de agua \(prioridad critica\)/

      assert {:ok, _, tabla} = cmd(coord, "list_needs zona=#{z}")
      assert tabla =~ "Punto de atención sector 3"
      assert tabla =~ "pendiente"
    end

    test "la descripción puede escribirse sin comillas" do
      ciudadano = conectar("ciudadano")
      z = "z#{unico()}"

      assert {:ok, _, _} =
               cmd(ciudadano, "register_need alimentos 5 alta #{z} necesitan comida urgente")

      assert {:ok, _, tabla} = cmd(ciudadano, "list_needs zona=#{z}")
      assert tabla =~ "necesitan comida urgente"
    end

    test "list_needs ordena por prioridad y filtra" do
      coord = conectar("coordinador")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_need agua 1 baja #{z} baja_desc")
      {:ok, _, _} = cmd(coord, "register_need rescate 2 critica #{z} critica_desc")
      {:ok, _, _} = cmd(coord, "register_need agua 3 media #{z} media_desc")

      {:ok, _, tabla} = cmd(coord, "list_needs zona=#{z}")
      assert posicion(tabla, "critica_desc") < posicion(tabla, "media_desc")
      assert posicion(tabla, "media_desc") < posicion(tabla, "baja_desc")

      {:ok, _, solo_agua} = cmd(coord, "list_needs zona=#{z} tipo=agua")
      assert solo_agua =~ "baja_desc"
      refute solo_agua =~ "critica_desc"

      {:ok, _, solo_critica} = cmd(coord, "list_needs zona=#{z} prioridad=crítica")
      assert solo_critica =~ "critica_desc"
      refute solo_critica =~ "media_desc"

      {:ok, _, ninguna} = cmd(coord, "list_needs zona=#{z} estado=atendida")
      assert ninguna == "(sin resultados)"
    end

    test "pending_needs muestra lo pendiente, lo más urgente primero" do
      coord = conectar("coordinador")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_need agua 1 media #{z} pend_media")
      {:ok, _, _} = cmd(coord, "register_need agua 1 critica #{z} pend_critica")

      assert {:ok, _, tabla} = cmd(coord, "pending_needs")
      assert posicion(tabla, "pend_critica") < posicion(tabla, "pend_media")
    end

    test "zone_status cuenta las necesidades de la zona" do
      coord = conectar("coordinador")
      z = "z#{unico()}"
      {:ok, _, _} = cmd(coord, "register_zone #{z} Centro alto")
      {:ok, _, _} = cmd(coord, "register_need agua 1 media #{z} una")
      {:ok, _, _} = cmd(coord, "register_need agua 1 media #{z} dos")
      {:ok, _, estado} = cmd(coord, "zone_status #{z}")
      assert estado =~ "Necesidades: 2 registradas, 2 pendientes"
    end

    test "errores de validación" do
      ciudadano = conectar("ciudadano")
      z = "z#{unico()}"
      assert cmd(ciudadano, "register_need pizza 5 alta #{z}") == {:error, :tipo_invalido}
      assert cmd(ciudadano, "register_need agua cinco alta #{z}") == {:error, :cantidad_invalida}
      assert cmd(ciudadano, "register_need agua -5 alta #{z}") == {:error, :cantidad_invalida}
      assert cmd(ciudadano, "register_need agua 5 urgente #{z}") == {:error, :prioridad_invalida}
      assert {:error, {:uso, _}} = cmd(ciudadano, "register_need agua 5")
      assert cmd(ciudadano, "list_needs tipo=pizza") == {:error, :tipo_invalido}
      assert cmd(ciudadano, "list_needs prioridad=urgente") == {:error, :prioridad_invalida}
      assert cmd(ciudadano, "list_needs estado=volando") == {:error, :estado_invalido}
    end

    test "sin sesión no se puede registrar" do
      assert cmd(Sesion.anonima(), "register_need agua 5 alta x") == {:error, :no_conectado}
    end
  end
end
