defmodule Emergencias.Servidores.NecesidadServerTest do
  # No async: usa el servidor global y el archivo necesidades.txt de pruebas.
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Necesidad
  alias Emergencias.Servidores.NecesidadServer

  defp zona, do: "z#{System.unique_integer([:positive])}"

  defp datos(zona, extra \\ %{}) do
    Map.merge(%{tipo: "agua", cantidad: 30, prioridad: "critica", zona: zona, descripcion: "Punto sector 3", reportado_por: "laura"}, extra)
  end

  defp registrar!(zona, extra \\ %{}) do
    {:ok, n} = NecesidadServer.registrar(datos(zona, extra))
    n
  end

  test "registrar asigna un id único, estado pendiente y fecha" do
    z = zona()
    assert {:ok, %Necesidad{} = n} = NecesidadServer.registrar(datos(z))
    assert n.id =~ ~r/^N\d{3,}$/
    assert n.estado == :pendiente
    assert n.reportado_por == "laura"
    assert %DateTime{} = n.creada_en
    assert {:ok, ^n} = NecesidadServer.obtener(n.id)
  end

  test "valida antes de modificar el estado" do
    z = zona()
    assert NecesidadServer.registrar(datos(z, %{cantidad: -5})) == {:error, :cantidad_invalida}
    assert NecesidadServer.registrar(datos(z, %{tipo: "pizza"})) == {:error, :tipo_invalido}
    assert NecesidadServer.registrar(datos(z, %{prioridad: "urgente"})) == {:error, :prioridad_invalida}
    assert NecesidadServer.listar(zona: z) == []
  end

  test "ids únicos aunque se registre en paralelo" do
    z = zona()

    ids =
      1..50
      |> Task.async_stream(fn _ -> NecesidadServer.registrar(datos(z)) end, max_concurrency: 50)
      |> Enum.map(fn {:ok, {:ok, n}} -> n.id end)

    assert length(Enum.uniq(ids)) == 50
    assert length(NecesidadServer.listar(zona: z)) == 50
  end

  test "listar filtra por zona, tipo, prioridad y estado" do
    z = zona()
    a = registrar!(z, %{tipo: "agua", prioridad: "alta"})
    b = registrar!(z, %{tipo: "rescate", prioridad: "critica"})
    _otra_zona = registrar!(zona())

    assert z |> then(&NecesidadServer.listar(zona: &1)) |> length() == 2
    assert [%{id: id}] = NecesidadServer.listar(zona: z, tipo: :rescate)
    assert id == b.id
    assert [%{id: id}] = NecesidadServer.listar(zona: z, prioridad: :alta)
    assert id == a.id

    {:ok, _} = NecesidadServer.cambiar_estado(a.id, :cancelada)
    assert [%{id: id}] = NecesidadServer.listar(zona: z, estado: :cancelada)
    assert id == a.id
  end

  test "la prioridad ordena: crítica primero, y a igual prioridad por llegada" do
    z = zona()
    baja = registrar!(z, %{prioridad: "baja"})
    critica1 = registrar!(z, %{prioridad: "critica"})
    media = registrar!(z, %{prioridad: "media"})
    critica2 = registrar!(z, %{prioridad: "critica"})

    ids = z |> then(&NecesidadServer.listar(zona: &1)) |> Enum.map(& &1.id)
    assert ids == [critica1.id, critica2.id, media.id, baja.id]
  end

  test "pendientes excluye las cerradas y las ya cubiertas" do
    z = zona()
    abierta = registrar!(z)
    cancelada = registrar!(z)
    cubierta = registrar!(z, %{cantidad: 10})

    {:ok, _} = NecesidadServer.cambiar_estado(cancelada.id, :cancelada)
    {:ok, _} = NecesidadServer.registrar_asignacion(cubierta.id, {"R001", "c", 10})

    ids = Enum.map(NecesidadServer.pendientes(), & &1.id)
    assert abierta.id in ids
    refute cancelada.id in ids
    refute cubierta.id in ids
  end

  test "registrar_asignacion acumula y no excede lo requerido" do
    n = registrar!(zona(), %{cantidad: 30})
    assert {:ok, %{cantidad_asignada: 20, estado: :asignada}} = NecesidadServer.registrar_asignacion(n.id, {"R001", "c1", 20})
    assert NecesidadServer.registrar_asignacion(n.id, {"R001", "c1", 11}) == {:error, :excede_requerido}
    assert {:ok, %{cantidad_asignada: 30}} = NecesidadServer.registrar_asignacion(n.id, {"R002", "c2", 10})
    assert NecesidadServer.registrar_asignacion("N999999", {"R001", "c", 1}) == {:error, :no_existe}
  end

  test "una necesidad cancelada no vuelve a consumir recursos" do
    n = registrar!(zona())
    {:ok, _} = NecesidadServer.cambiar_estado(n.id, :cancelada)
    assert NecesidadServer.registrar_asignacion(n.id, {"R001", "c", 1}) == {:error, :necesidad_cerrada}
  end

  test "CONCURRENCIA: cancelar la misma necesidad 20 veces a la vez solo se confirma una" do
    n = registrar!(zona())

    resultados =
      1..20
      |> Task.async_stream(fn _ -> NecesidadServer.cambiar_estado(n.id, :cancelada) end, max_concurrency: 20)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &(&1 == {:error, :necesidad_cerrada})) == 19
  end

  test "CONCURRENCIA: asignaciones simultáneas nunca superan lo requerido" do
    n = registrar!(zona(), %{cantidad: 50})

    resultados =
      1..30
      |> Task.async_stream(fn i -> NecesidadServer.registrar_asignacion(n.id, {"R#{i}", "c", 5}) end, max_concurrency: 30)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 10
    assert {:ok, %{cantidad_asignada: 50}} = NecesidadServer.obtener(n.id)
  end

  test "transiciones inválidas" do
    n = registrar!(zona())
    assert NecesidadServer.cambiar_estado(n.id, :atendida) == {:error, :transicion_invalida}
    assert NecesidadServer.cambiar_estado("N999999", :cancelada) == {:error, :no_existe}
  end

  test "supervisión: tras caerse el servidor se recuperan los datos y la numeración continúa" do
    z = zona()
    antes = registrar!(z)

    viejo = Process.whereis(NecesidadServer)
    ref = Process.monitor(viejo)
    Process.exit(viejo, :kill)
    assert_receive {:DOWN, ^ref, :process, ^viejo, :killed}
    esperar_reinicio(viejo, 100)

    assert NecesidadServer.obtener(antes.id) == {:ok, antes}
    despues = registrar!(z)
    refute despues.id == antes.id
    assert numero(despues.id) > numero(antes.id)
  end

  defp numero("N" <> resto), do: String.to_integer(resto)

  defp esperar_reinicio(_viejo, 0), do: flunk("el supervisor no reinició NecesidadServer")

  defp esperar_reinicio(viejo, intentos) do
    case Process.whereis(NecesidadServer) do
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
