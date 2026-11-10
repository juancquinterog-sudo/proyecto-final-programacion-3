defmodule Emergencias.Dominio.AlbergueTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Albergue

  defp albergue(capacidad) do
    {:ok, a} = Albergue.nuevo(%{codigo: "A01", nombre: "Albergue Norte", zona: "zona_norte", capacidad: capacidad})
    a
  end

  describe "nuevo/1" do
    test "crea un albergue vacío" do
      a = albergue(150)
      assert Albergue.ocupacion(a) == 0
      assert Albergue.cupos(a) == 150
      assert Albergue.porcentaje_ocupacion(a) == 0.0
    end

    test "valida los datos" do
      datos = %{codigo: "A", nombre: "N", zona: "z", capacidad: 10}
      assert Albergue.nuevo(%{datos | capacidad: -1}) == {:error, :cantidad_invalida}
      assert Albergue.nuevo(%{datos | capacidad: "mucha"}) == {:error, :cantidad_invalida}
      assert Albergue.nuevo(%{datos | codigo: ""}) == {:error, :texto_vacio}
    end
  end

  describe "ingresar/2" do
    test "respeta la capacidad máxima" do
      a = albergue(2)
      assert {:ok, a} = Albergue.ingresar(a, "111")
      assert {:ok, a} = Albergue.ingresar(a, "222")
      assert Albergue.ocupacion(a) == 2
      assert Albergue.cupos(a) == 0
      assert Albergue.ingresar(a, "333") == {:error, :sin_cupo}
      assert Albergue.porcentaje_ocupacion(a) == 100.0
    end

    test "la misma persona no ingresa dos veces" do
      {:ok, a} = Albergue.ingresar(albergue(5), "111")
      assert Albergue.ingresar(a, "111") == {:error, :ya_ingresado}
      assert Albergue.ocupacion(a) == 1
    end

    test "documento vacío" do
      assert Albergue.ingresar(albergue(5), "  ") == {:error, :texto_vacio}
    end

    test "un albergue de capacidad 0 no admite a nadie" do
      assert Albergue.ingresar(albergue(0), "111") == {:error, :sin_cupo}
    end
  end

  describe "salir/2" do
    test "libera un cupo" do
      a = albergue(1)
      {:ok, a} = Albergue.ingresar(a, "111")
      assert {:ok, a} = Albergue.salir(a, "111")
      assert Albergue.cupos(a) == 1
      assert {:ok, _} = Albergue.ingresar(a, "222")
    end

    test "no puede salir quien no está" do
      assert Albergue.salir(albergue(5), "999") == {:error, :no_esta_en_albergue}
    end
  end

  test "porcentaje de ocupación" do
    {:ok, a} = Albergue.ingresar(albergue(4), "1")
    assert Albergue.porcentaje_ocupacion(a) == 25.0
  end
end
