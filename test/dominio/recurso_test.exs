defmodule Emergencias.Dominio.RecursoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.{Movimiento, Recurso}

  @fecha ~U[2026-11-10 12:00:00Z]
  @meta %{usuario: "laura", fecha: @fecha}

  defp recurso(cantidad \\ 50) do
    {:ok, r} =
      Recurso.nuevo(%{
        codigo: "R001",
        nombre: "Agua potable",
        categoria: "agua",
        unidad: "litros",
        cantidad: cantidad,
        ubicacion: "centro_acopio_1",
        usuario: "laura",
        fecha: @fecha
      })

    r
  end

  describe "nuevo/1" do
    test "con stock inicial registra una entrada" do
      r = recurso()
      assert r.existencias == %{"centro_acopio_1" => 50}

      assert [
               %Movimiento{
                 tipo: :entrada,
                 cantidad: 50,
                 ubicacion: "centro_acopio_1",
                 usuario: "laura"
               }
             ] = r.historial
    end

    test "sin stock inicial queda vacío" do
      {:ok, r} =
        Recurso.nuevo(%{codigo: "R2", nombre: "Arroz", categoria: :alimentos, unidad: "kg"})

      assert r.existencias == %{}
      assert r.historial == []
    end

    test "valida los datos" do
      base = %{codigo: "R", nombre: "N", categoria: "agua", unidad: "l"}
      assert Recurso.nuevo(%{base | codigo: ""}) == {:error, :texto_vacio}
      assert Recurso.nuevo(%{base | categoria: "ropa"}) == {:error, :tipo_invalido}
      assert Recurso.nuevo(Map.put(base, :cantidad, -1)) == {:error, :cantidad_invalida}
      # cantidad > 0 exige ubicación
      assert Recurso.nuevo(Map.put(base, :cantidad, 5)) == {:error, :ubicacion_invalida}
    end
  end

  describe "entrada/4" do
    test "suma stock y registra el movimiento (el más reciente primero)" do
      {:ok, r} = Recurso.entrada(recurso(), "centro_acopio_1", 25, @meta)
      assert Recurso.disponible(r, "centro_acopio_1") == 75
      assert length(r.historial) == 2
      assert hd(r.historial).cantidad == 25
    end

    test "rechaza cantidades no positivas" do
      assert Recurso.entrada(recurso(), "c", 0, @meta) == {:error, :cantidad_invalida}
      assert Recurso.entrada(recurso(), "c", -5, @meta) == {:error, :cantidad_invalida}
      assert Recurso.entrada(recurso(), "", 5, @meta) == {:error, :ubicacion_invalida}
    end
  end

  describe "salida/4 y asignar/5" do
    test "salida descuenta del inventario" do
      {:ok, r} = Recurso.salida(recurso(), "centro_acopio_1", 20, @meta)
      assert Recurso.disponible(r, "centro_acopio_1") == 30
      assert hd(r.historial).tipo == :salida
    end

    test "salida mayor al stock retorna :stock_insuficiente y no cambia nada" do
      r = recurso()
      assert Recurso.salida(r, "centro_acopio_1", 51, @meta) == {:error, :stock_insuficiente}
      assert Recurso.salida(r, "otra_ubicacion", 1, @meta) == {:error, :stock_insuficiente}
    end

    test "asignar registra la referencia a la necesidad" do
      {:ok, r} = Recurso.asignar(recurso(), "centro_acopio_1", 30, "N001", @meta)
      assert Recurso.disponible(r, "centro_acopio_1") == 20
      assert %Movimiento{tipo: :asignacion, referencia: "N001", cantidad: 30} = hd(r.historial)
    end

    test "escenario del enunciado: 30 + 25 sobre 50 (secuencial)" do
      {:ok, r} = Recurso.asignar(recurso(), "centro_acopio_1", 30, "N001", @meta)

      assert Recurso.asignar(r, "centro_acopio_1", 25, "N002", @meta) ==
               {:error, :stock_insuficiente}

      assert Recurso.disponible(r, "centro_acopio_1") == 20
    end

    test "las existencias nunca quedan negativas" do
      {:ok, r} = Recurso.salida(recurso(), "centro_acopio_1", 50, @meta)
      assert Recurso.disponible(r, "centro_acopio_1") == 0
      assert Recurso.salida(r, "centro_acopio_1", 1, @meta) == {:error, :stock_insuficiente}
    end
  end

  describe "transferir/5" do
    test "mueve cantidad entre ubicaciones conservando el total" do
      {:ok, r} = Recurso.transferir(recurso(), "centro_acopio_1", "albergue_2", 30, @meta)
      assert r.existencias == %{"centro_acopio_1" => 20, "albergue_2" => 30}
      assert Recurso.total(r) == 50

      assert [
               %Movimiento{tipo: :transferencia_entrada},
               %Movimiento{tipo: :transferencia_salida} | _
             ] = r.historial
    end

    test "errores" do
      r = recurso()

      assert Recurso.transferir(r, "centro_acopio_1", "albergue_2", 51, @meta) ==
               {:error, :stock_insuficiente}

      assert Recurso.transferir(r, "centro_acopio_1", "centro_acopio_1", 5, @meta) ==
               {:error, :misma_ubicacion}

      assert Recurso.transferir(r, "centro_acopio_1", "albergue_2", 0, @meta) ==
               {:error, :cantidad_invalida}

      assert Recurso.transferir(r, "", "albergue_2", 5, @meta) == {:error, :ubicacion_invalida}
    end
  end

  test "con_stock lista las ubicaciones de mayor a menor y omite las vacías" do
    {:ok, r} = Recurso.transferir(recurso(), "centro_acopio_1", "albergue_2", 30, @meta)
    {:ok, r} = Recurso.transferir(r, "centro_acopio_1", "vacio", 20, @meta)
    {:ok, r} = Recurso.salida(r, "vacio", 20, @meta)
    assert Recurso.con_stock(r) == [{"albergue_2", 30}]
  end
end
