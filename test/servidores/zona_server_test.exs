defmodule Emergencias.Servidores.ZonaServerTest do
  # No async: usa el servidor global y el archivo zonas.txt de pruebas.
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Zona
  alias Emergencias.Servidores.ZonaServer

  defp codigo, do: "z#{System.unique_integer([:positive])}"

  defp registrar(c \\ nil) do
    c = c || codigo()

    {:ok, _} =
      ZonaServer.registrar(%{
        codigo: c,
        nombre: "Zona #{c}",
        nivel: "alto",
        personas_estimadas: 10
      })

    c
  end

  test "registrar y consultar" do
    c = codigo()

    assert {:ok, %Zona{codigo: ^c, nivel: :alto, personas_estimadas: 10}} =
             ZonaServer.registrar(%{
               codigo: c,
               nombre: "Centro",
               nivel: "alto",
               personas_estimadas: 10
             })

    assert {:ok, %Zona{codigo: ^c}} = ZonaServer.consultar(c)
    assert ZonaServer.consultar("no_existe_#{c}") == {:error, :no_existe}
  end

  test "los identificadores no se repiten" do
    c = registrar()

    assert ZonaServer.registrar(%{codigo: c, nombre: "otra", nivel: "bajo"}) ==
             {:error, :id_duplicado}
  end

  test "valida los datos antes de modificar el estado" do
    c = codigo()

    assert ZonaServer.registrar(%{codigo: c, nombre: "X", nivel: "gigante"}) ==
             {:error, :nivel_invalido}

    assert ZonaServer.registrar(%{codigo: c, nombre: "X", nivel: "alto", personas_estimadas: -3}) ==
             {:error, :cantidad_invalida}

    assert ZonaServer.consultar(c) == {:error, :no_existe}
  end

  test "sectores y puntos de atención" do
    c = registrar()

    assert {:ok, _} =
             ZonaServer.agregar_sector(c, %{
               codigo: "s1",
               nombre: "Sector 1",
               nivel: "critico",
               personas_estimadas: 20
             })

    assert {:ok, _} =
             ZonaServer.agregar_punto(c, "s1", %{
               codigo: "p1",
               nombre: "Punto 1",
               personas_estimadas: 5
             })

    assert ZonaServer.agregar_sector(c, %{codigo: "s1", nombre: "repetido"}) ==
             {:error, :sector_duplicado}

    assert ZonaServer.agregar_punto(c, "s1", %{codigo: "p1", nombre: "repetido"}) ==
             {:error, :punto_duplicado}

    assert ZonaServer.agregar_punto(c, "nada", %{codigo: "p9", nombre: "x"}) ==
             {:error, :sector_no_existe}

    assert ZonaServer.agregar_sector("no_existe_#{c}", %{codigo: "s", nombre: "x"}) ==
             {:error, :no_existe}

    assert {:ok, est} = ZonaServer.estadisticas(c)
    assert est.total_afectados == 10 + 20 + 5
    assert est.sectores == 1
    assert est.puntos == 1
    assert est.por_nivel == %{critico: 1}
  end

  test "listar devuelve las zonas ordenadas por código" do
    a = registrar()
    b = registrar()
    codigos = Enum.map(ZonaServer.listar(), & &1.codigo)
    assert a in codigos and b in codigos
    assert codigos == Enum.sort(codigos)
  end

  test "dos solicitudes simultáneas con el mismo código: solo una se confirma" do
    c = codigo()

    resultados =
      1..20
      |> Task.async_stream(
        fn _ -> ZonaServer.registrar(%{codigo: c, nombre: "Z", nivel: "bajo"}) end,
        max_concurrency: 20
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &(&1 == {:error, :id_duplicado})) == 19
  end

  test "supervisión: tras caerse el servidor las zonas se recuperan del archivo" do
    c = registrar()

    {:ok, _} =
      ZonaServer.agregar_sector(c, %{codigo: "s1", nombre: "Sector 1", personas_estimadas: 7})

    {:ok, antes} = ZonaServer.consultar(c)

    viejo = Process.whereis(ZonaServer)
    ref = Process.monitor(viejo)
    Process.exit(viejo, :kill)
    assert_receive {:DOWN, ^ref, :process, ^viejo, :killed}
    esperar_reinicio(viejo, 100)

    assert ZonaServer.consultar(c) == {:ok, antes}
  end

  defp esperar_reinicio(_viejo, 0), do: flunk("el supervisor no reinició ZonaServer")

  defp esperar_reinicio(viejo, intentos) do
    case Process.whereis(ZonaServer) do
      nil -> reintentar(viejo, intentos)
      ^viejo -> reintentar(viejo, intentos)
      _nuevo -> :ok
    end
  end

  defp reintentar(viejo, intentos) do
    Process.sleep(20)
    esperar_reinicio(viejo, intentos - 1)
  end
end
