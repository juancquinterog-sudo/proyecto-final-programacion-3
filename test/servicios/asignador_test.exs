defmodule Emergencias.Servicios.AsignadorTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Recurso
  alias Emergencias.Servicios.Asignador
  alias Emergencias.Servidores.{NecesidadServer, RecursoServer}

  defp recurso(codigo, ubicacion, cantidad, categoria) do
    {:ok, r} =
      Recurso.nuevo(%{
        codigo: codigo,
        nombre: codigo,
        categoria: categoria,
        unidad: "litros",
        cantidad: cantidad,
        ubicacion: ubicacion
      })

    {:ok, _} = RecursoServer.registrar(r)
    codigo
  end

  defp necesidad(cantidad, tipo) do
    {:ok, n} =
      NecesidadServer.registrar(%{
        tipo: tipo,
        cantidad: cantidad,
        prioridad: "critica",
        zona: "centro"
      })

    n.id
  end

  defp uniq(prefijo), do: "#{prefijo}#{System.unique_integer([:positive])}"

  # Cada test usa una categoría propia (otra) para no competir con el resto: usamos "otra" + stock exacto
  setup do
    # Vacía el inventario de agua de otros tests para que los conteos sean exactos
    for r <- RecursoServer.listar(), to_string(r.categoria) == "transporte" do
      for {ub, c} <- r.existencias, c > 0, do: RecursoServer.salida(r.codigo, ub, c)
    end

    :ok
  end

  test "toma de varios recursos cuando uno solo no alcanza" do
    a = recurso(uniq("TA"), "c1", 15, "transporte")
    b = recurso(uniq("TB"), "c2", 20, "transporte")
    id = necesidad(30, "transporte")

    assert {:ok, %{necesidad: ^id, tomado: tomado}} =
             Asignador.asignar(id, "transporte", 30, "laura")

    assert tomado |> Enum.map(&elem(&1, 2)) |> Enum.sum() == 30
    assert length(tomado) == 2
    {:ok, ra} = RecursoServer.consultar(a)
    {:ok, rb} = RecursoServer.consultar(b)
    assert Recurso.total(ra) + Recurso.total(rb) == 5
    assert {:ok, n} = NecesidadServer.obtener(id)
    assert n.cantidad_asignada == 30 and n.estado == :asignada
  end

  test "stock insuficiente: rollback total y la necesidad queda intacta" do
    cod = recurso(uniq("RB"), "c1", 10, "refugio")
    id = necesidad(20, "refugio")
    assert {:error, :stock_insuficiente} = Asignador.asignar(id, "refugio", 20, "laura")
    {:ok, r} = RecursoServer.consultar(cod)
    assert Recurso.total(r) == 10
    assert {:ok, %{cantidad_asignada: 0, estado: :pendiente}} = NecesidadServer.obtener(id)
  end

  test "errores de validación" do
    assert {:error, :no_existe} = Asignador.asignar("N_NO_EXISTE", "agua", 5, "x")
    id = necesidad(10, "rescate")
    assert {:error, :categoria_distinta} = Asignador.asignar(id, "agua", 5, "x")
    assert {:error, :excede_requerido} = Asignador.asignar(id, "rescate", 11, "x")
    assert {:error, :cantidad_invalida} = Asignador.asignar(id, "rescate", "abc", "x")
  end

  test "una necesidad cancelada no vuelve a consumir recursos" do
    cod = recurso(uniq("RC"), "c1", 50, "primeros_auxilios")
    id = necesidad(10, "primeros_auxilios")
    {:ok, _} = NecesidadServer.cambiar_estado(id, :cancelada)
    assert {:error, :necesidad_cerrada} = Asignador.asignar(id, "primeros_auxilios", 10, "x")
    {:ok, r} = RecursoServer.consultar(cod)
    assert Recurso.total(r) == 50
  end

  test "escenario del PDF: 30 L y 25 L sobre 50 L en paralelo -> solo una se confirma" do
    cod = recurso(uniq("PDF"), "centro_acopio_1", 50, "alimentos")
    n1 = necesidad(30, "alimentos")
    n2 = necesidad(25, "alimentos")

    resultados =
      [n1, n2]
      |> Enum.zip([30, 25])
      |> Task.async_stream(fn {id, c} -> Asignador.asignar(id, "alimentos", c, "u") end,
        max_concurrency: 2
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, :stock_insuficiente}, &1)) == 1
    {:ok, r} = RecursoServer.consultar(cod)
    assert Recurso.total(r) in [20, 25]
  end

  test "carga: muchas solicitudes simultáneas nunca superan el inventario" do
    cod = recurso(uniq("LOAD"), "c1", 50, "medicamentos")
    ids = for _ <- 1..30, do: necesidad(5, "medicamentos")

    exitos =
      ids
      |> Task.async_stream(
        fn id ->
          Asignador.asignar(id, "medicamentos", 5, "u")
        end,
        max_concurrency: 30,
        timeout: 30_000
      )
      |> Enum.count(fn {:ok, r} -> match?({:ok, _}, r) end)

    assert exitos == 10

    {:ok, r} = RecursoServer.consultar(cod)
    assert Recurso.total(r) == 0
    assert Enum.all?(r.existencias, fn {_, c} -> c >= 0 end)
  end
end
