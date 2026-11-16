defmodule Emergencias.Servidores.RecursoAlbergueServerTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.{Albergue, Recurso}
  alias Emergencias.Servidores.{AlbergueServer, RecursoServer}

  defp uniq(p), do: "#{p}#{System.unique_integer([:positive])}"

  describe "RecursoServer" do
    setup do
      codigo = uniq("R")

      {:ok, r} =
        Recurso.nuevo(%{
          codigo: codigo,
          nombre: "Agua",
          categoria: "agua",
          unidad: "litros",
          cantidad: 50,
          ubicacion: "a"
        })

      {:ok, _} = RecursoServer.registrar(r)
      %{codigo: codigo}
    end

    test "registrar duplicado y consultar", %{codigo: c} do
      {:ok, r} = Recurso.nuevo(%{codigo: c, nombre: "x", categoria: "agua", unidad: "l"})
      assert {:error, :id_duplicado} = RecursoServer.registrar(r)
      assert {:ok, %Recurso{codigo: ^c}} = RecursoServer.consultar(c)
      assert {:error, :no_existe} = RecursoServer.consultar("NOPE")
      assert Enum.any?(RecursoServer.listar(), &(&1.codigo == c))
    end

    test "entradas, salidas y nunca negativo", %{codigo: c} do
      assert {:ok, r} = RecursoServer.entrada(c, "a", 10)
      assert Recurso.total(r) == 60
      assert {:ok, r} = RecursoServer.salida(c, "a", 60)
      assert Recurso.total(r) == 0
      assert {:error, :stock_insuficiente} = RecursoServer.salida(c, "a", 1)
      assert {:error, :cantidad_invalida} = RecursoServer.entrada(c, "a", -5)
      assert {:error, :no_existe} = RecursoServer.entrada("NOPE", "a", 1)
    end

    test "reservar / liberar / transferir conservan el historial", %{codigo: c} do
      assert {:ok, _} = RecursoServer.reservar(c, "a", 20, "N1")
      assert {:error, :stock_insuficiente} = RecursoServer.reservar(c, "a", 31, "N2")
      assert {:ok, _} = RecursoServer.liberar(c, "a", 20, "N1")
      assert {:ok, r} = RecursoServer.transferir(c, "a", "b", 30)
      assert r.existencias == %{"a" => 20, "b" => 30}
      assert {:error, :misma_ubicacion} = RecursoServer.transferir(c, "a", "a", 1)
      assert {:error, :stock_insuficiente} = RecursoServer.transferir(c, "a", "b", 999)
      assert length(r.historial) >= 4
    end

    test "reservas concurrentes nunca superan el stock", %{codigo: c} do
      resultados =
        1..40
        |> Task.async_stream(fn i -> RecursoServer.reservar(c, "a", 5, "N#{i}") end,
          max_concurrency: 40
        )
        |> Enum.map(fn {:ok, r} -> r end)

      assert Enum.count(resultados, &match?({:ok, _}, &1)) == 10
      {:ok, r} = RecursoServer.consultar(c)
      assert Recurso.total(r) == 0
    end

    test "persiste en recursos.txt y movimientos.txt", %{codigo: c} do
      RecursoServer.persistir()
      assert File.read!(Emergencias.Persistencia.Almacen.ruta(:recursos)) =~ c
      assert File.read!(Emergencias.Persistencia.Almacen.ruta(:movimientos)) =~ c
    end
  end

  describe "AlbergueServer" do
    setup do
      codigo = uniq("A")
      {:ok, a} = Albergue.nuevo(%{codigo: codigo, nombre: "Norte", zona: "z", capacidad: 3})
      {:ok, _} = AlbergueServer.registrar(a)
      %{codigo: codigo}
    end

    test "duplicado y consulta", %{codigo: c} do
      {:ok, a} = Albergue.nuevo(%{codigo: c, nombre: "x", zona: "z", capacidad: 1})
      assert {:error, :id_duplicado} = AlbergueServer.registrar(a)
      assert {:ok, %Albergue{capacidad: 3}} = AlbergueServer.consultar(c)
      assert {:error, :no_existe} = AlbergueServer.consultar("NOPE")
      assert Enum.any?(AlbergueServer.listar(), &(&1.codigo == c))
    end

    test "ingreso, salida y reglas", %{codigo: c} do
      assert {:ok, a} = AlbergueServer.registrar_entrada(c, "1")
      assert Albergue.ocupacion(a) == 1
      assert {:error, :ya_ingresado} = AlbergueServer.registrar_entrada(c, "1")
      assert {:ok, _} = AlbergueServer.registrar_salida(c, "1")
      assert {:error, :no_esta_en_albergue} = AlbergueServer.registrar_salida(c, "1")
    end

    test "10 personas simultáneas, capacidad 3: solo 3 ingresan", %{codigo: c} do
      resultados =
        1..10
        |> Task.async_stream(fn i -> AlbergueServer.registrar_entrada(c, "doc#{i}") end,
          max_concurrency: 10
        )
        |> Enum.map(fn {:ok, r} -> r end)

      assert Enum.count(resultados, &match?({:ok, _}, &1)) == 3
      assert Enum.count(resultados, &match?({:error, :sin_cupo}, &1)) == 7
      {:ok, a} = AlbergueServer.consultar(c)
      assert Albergue.ocupacion(a) == 3
    end
  end
end

defmodule Emergencias.Persistencia.RestauradorTest do
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.{Albergue, Recurso}
  alias Emergencias.Persistencia.Restaurador
  alias Emergencias.Servidores.{AlbergueServer, RecursoServer}

  test "tras caerse los procesos, el Restaurador recupera recursos (con historial) y albergues desde disco" do
    n = System.unique_integer([:positive])
    codigo = "RES#{n}"
    cod_a = "ALB#{n}"

    {:ok, r} =
      Recurso.nuevo(%{
        codigo: codigo,
        nombre: "Agua",
        categoria: "agua",
        unidad: "l",
        cantidad: 40,
        ubicacion: "a"
      })

    {:ok, _} = RecursoServer.registrar(r)
    {:ok, _} = RecursoServer.reservar(codigo, "a", 15, "N1")
    {:ok, alb} = Albergue.nuevo(%{codigo: cod_a, nombre: "Sur", zona: "z", capacidad: 5})
    {:ok, _} = AlbergueServer.registrar(alb)
    {:ok, _} = AlbergueServer.registrar_entrada(cod_a, "77")

    [{pid_r, _}] = Registry.lookup(Emergencias.Registry, {:recurso, codigo})
    [{pid_a, _}] = Registry.lookup(Emergencias.Registry, {:albergue, cod_a})
    :ok = DynamicSupervisor.terminate_child(Emergencias.RecursoDinamico, pid_r)
    :ok = DynamicSupervisor.terminate_child(Emergencias.AlbergueDinamico, pid_a)
    assert {:error, :no_existe} = RecursoServer.consultar(codigo)

    Restaurador.ejecutar(:recursos)
    Restaurador.ejecutar(:albergues)

    assert {:ok, recuperado} = RecursoServer.consultar(codigo)
    assert Recurso.total(recuperado) == 25
    assert length(recuperado.historial) == 2
    assert {:ok, alb2} = AlbergueServer.consultar(cod_a)
    assert Albergue.ocupacion(alb2) == 1
  end
end
