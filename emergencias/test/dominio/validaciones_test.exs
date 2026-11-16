defmodule Emergencias.Dominio.ValidacionesTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Validaciones, as: V

  describe "entero_positivo/1" do
    test "acepta enteros y textos numéricos" do
      assert V.entero_positivo(30) == {:ok, 30}
      assert V.entero_positivo("30") == {:ok, 30}
      assert V.entero_positivo(" 7 ") == {:ok, 7}
    end

    test "rechaza cero, negativos y valores no numéricos" do
      for valor <- [0, -5, "0", "-3", "abc", "3.5", "", nil, 2.5] do
        assert V.entero_positivo(valor) == {:error, :cantidad_invalida}
      end
    end
  end

  describe "entero_no_negativo/1" do
    test "acepta cero" do
      assert V.entero_no_negativo("0") == {:ok, 0}
      assert V.entero_no_negativo(10) == {:ok, 10}
    end

    test "rechaza negativos" do
      assert V.entero_no_negativo(-1) == {:error, :cantidad_invalida}
      assert V.entero_no_negativo("-1") == {:error, :cantidad_invalida}
    end
  end

  describe "texto_no_vacio/1" do
    test "recorta espacios" do
      assert V.texto_no_vacio("  hola ") == {:ok, "hola"}
    end

    test "rechaza vacío y no-texto" do
      assert V.texto_no_vacio("   ") == {:error, :texto_vacio}
      assert V.texto_no_vacio(nil) == {:error, :texto_vacio}
      assert V.texto_no_vacio(123) == {:error, :texto_vacio}
    end
  end

  describe "catálogos" do
    test "prioridad acepta texto con o sin tilde y mayúsculas" do
      assert V.prioridad("critica") == {:ok, :critica}
      assert V.prioridad("Crítica") == {:ok, :critica}
      assert V.prioridad(:baja) == {:ok, :baja}
      assert V.prioridad("urgente") == {:error, :prioridad_invalida}
    end

    test "nivel" do
      assert V.nivel("critico") == {:ok, :critico}
      assert V.nivel("bajo") == {:ok, :bajo}
      assert V.nivel("x") == {:error, :nivel_invalido}
    end

    test "tipo_necesidad normaliza espacios y guiones" do
      assert V.tipo_necesidad("agua") == {:ok, :agua}
      assert V.tipo_necesidad("primeros auxilios") == {:ok, :primeros_auxilios}
      assert V.tipo_necesidad("otro") == {:ok, :otra}
      assert V.tipo_necesidad("pizza") == {:error, :tipo_invalido}
    end

    test "tipo_usuario" do
      assert V.tipo_usuario("coordinador") == {:ok, :coordinador}
      assert V.tipo_usuario("coordinadora") == {:ok, :coordinador}
      assert V.tipo_usuario("jefe") == {:error, :tipo_usuario_invalido}
    end

    test "tipo_reporte" do
      assert V.tipo_reporte("lost") == {:ok, :perdida}
      assert V.tipo_reporte("found") == {:ok, :encontrada}
      assert V.tipo_reporte("otro") == {:error, :tipo_reporte_invalido}
    end

    test "estado según la entidad" do
      assert V.estado(:necesidad, "en_atencion") == {:ok, :en_atencion}
      assert V.estado(:persona, "en albergue") == {:ok, :en_albergue}
      assert V.estado(:necesidad, "en_albergue") == {:error, :estado_invalido}
    end
  end

  describe "id_libre?/2" do
    test "detecta duplicados" do
      assert V.id_libre?("N001", ["N002"]) == :ok
      assert V.id_libre?("N001", ["N001", "N002"]) == {:error, :id_duplicado}
      assert V.id_libre?("N001", MapSet.new(["N001"])) == {:error, :id_duplicado}
    end
  end
end
