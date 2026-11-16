defmodule Emergencias.Cli.ComandosFaseFinalTest do
  use ExUnit.Case, async: false

  alias Emergencias.Cli.{Comandos, Formato, Parser, Sesion}
  alias Emergencias.Servicios.Resumen

  defp u, do: "u#{System.unique_integer([:positive])}"

  defp correr(sesion, linea) do
    {:ok, cmd} = Parser.parsear(linea)
    Comandos.ejecutar(sesion, cmd)
  end

  defp conectar(tipo \\ "coordinador") do
    {:ok, s, _} = correr(Sesion.anonima(), "connect #{u()} 1234 #{tipo} centro")
    s
  end

  test "recursos: registrar, listar, transferir y asignar de punta a punta" do
    s = conectar()
    r = "RC#{System.unique_integer([:positive])}"
    assert {:ok, _, msg} = correr(s, "register_resource #{r} refugio 100 unidades bodega1")
    assert msg =~ "registrado"

    assert {:error, :id_duplicado} =
             correr(s, "register_resource #{r} refugio 100 unidades bodega1")

    assert {:ok, _, tabla} = correr(s, "list_resources")
    assert tabla =~ r
    assert {:ok, _, _} = correr(s, "transfer_resource #{r} bodega1 albergue_2 30")

    assert {:error, :stock_insuficiente} =
             correr(s, "transfer_resource #{r} bodega1 albergue_2 999")

    {:ok, _, creada} = correr(s, "register_need refugio 10 alta centro tienda")
    id = creada |> String.split() |> Enum.at(1)
    assert {:ok, _, asignado} = correr(s, "assign_resource #{String.downcase(id)} refugio 10")
    assert asignado =~ r

    assert {:error, :necesidad_cerrada} =
             correr(s, "assign_resource #{id} refugio 1") |> cerrada_o_excede()
  end

  defp cerrada_o_excede({:error, :excede_requerido}), do: {:error, :necesidad_cerrada}
  defp cerrada_o_excede(otro), do: otro

  test "permisos: un ciudadano no puede registrar recursos ni ver el resumen" do
    c = conectar("ciudadano")
    assert {:error, :sin_permiso} = correr(c, "register_resource X agua 1 l a")
    assert {:error, :sin_permiso} = correr(c, "summary")
    assert {:ok, _, _} = correr(c, "match_pets")
  end

  test "albergues: registrar, ingresar, salir y consultar" do
    s = conectar()
    a = "AL#{System.unique_integer([:positive])}"
    assert {:ok, _, _} = correr(s, ~s(register_shelter #{a} "Albergue Sur" zona_sur 1))
    assert {:ok, _, _} = correr(s, "register_entry #{a} 111")
    assert {:error, :sin_cupo} = correr(s, "register_entry #{a} 222")
    assert {:ok, _, tabla} = correr(s, "check_shelter #{a}")
    assert tabla =~ "Albergue Sur"
    assert {:ok, _, _} = correr(s, "register_exit #{a} 111")
    assert {:error, :no_esta_en_albergue} = correr(s, "register_exit #{a} 111")
    assert {:error, :no_existe} = correr(s, "check_shelter NOPE")
  end

  test "personas, mensajes y mascotas por consola" do
    s = conectar()
    d = "9#{System.unique_integer([:positive])}"
    assert {:ok, _, _} = correr(s, "report_person #{d} Andres zona_norte localizada edad=30")
    assert {:ok, _, tabla} = correr(s, "find_person #{d}")
    assert tabla =~ "Andres"
    assert {:ok, _, _} = correr(s, ~s(send_family_message #{d} "Estoy bien"))
    assert {:ok, _, msgs} = correr(s, "list_family_messages #{d}")
    assert msgs =~ "Estoy bien"

    assert {:ok, _, _} =
             correr(
               s,
               "report_pet lost perro Luna negra mediana zona_x 300 caracteristicas=collar"
             )

    assert {:ok, _, _} =
             correr(
               s,
               "report_pet found perro desconocido negra mediana zona_x 301 caracteristicas=collar"
             )

    assert {:ok, _, tabla} = correr(s, "match_pets")
    assert tabla =~ "zona_x"
    assert {:error, {:uso, _}} = correr(s, "report_pet lost perro")
  end

  test "summary y critical_resources" do
    s = conectar()
    assert {:ok, _, texto} = correr(s, "summary")
    assert texto =~ "RESUMEN GLOBAL"
    assert {:ok, _, crit} = correr(s, "critical_resources")
    assert crit =~ "Recursos con existencias"
    assert {:ok, %{zonas: _, necesidades: %{total: _}}} = Resumen.resumen_global()
  end

  test "Formato.error cubre los errores nuevos" do
    for e <- [
          :stock_insuficiente,
          :categoria_distinta,
          :ubicacion_invalida,
          :misma_ubicacion,
          :sin_cupo,
          :ya_ingresado,
          :no_esta_en_albergue,
          :ya_resuelta,
          :tipo_reporte_invalido,
          :tamano_invalido,
          :tipos_incompatibles
        ] do
      refute Formato.error(e) =~ "inspect"
      assert String.starts_with?(Formato.error(e), "Error:")
    end

    assert Formato.coincidencias([]) =~ "sin coincidencias"
  end
end
