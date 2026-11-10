defmodule Emergencias.Dominio.NecesidadTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Necesidad

  @datos %{id: "N001", tipo: "agua", cantidad: 30, zona: "centro", prioridad: "critica"}

  defp nec(id, prioridad), do: %Necesidad{id: id, tipo: :agua, cantidad: 10, zona: "z", prioridad: prioridad}

  describe "nueva/1" do
    test "crea una necesidad pendiente" do
      assert {:ok, n} = Necesidad.nueva(Map.put(@datos, :descripcion, "Punto sector 3"))
      assert n.id == "N001"
      assert n.tipo == :agua
      assert n.prioridad == :critica
      assert n.estado == :pendiente
      assert n.cantidad_asignada == 0
      assert n.asignaciones == []
      assert n.descripcion == "Punto sector 3"
    end

    test "valida los datos" do
      assert Necesidad.nueva(%{@datos | cantidad: -3}) == {:error, :cantidad_invalida}
      assert Necesidad.nueva(%{@datos | cantidad: 0}) == {:error, :cantidad_invalida}
      assert Necesidad.nueva(%{@datos | cantidad: "abc"}) == {:error, :cantidad_invalida}
      assert Necesidad.nueva(%{@datos | tipo: "pizza"}) == {:error, :tipo_invalido}
      assert Necesidad.nueva(%{@datos | prioridad: "urgente"}) == {:error, :prioridad_invalida}
      assert Necesidad.nueva(%{@datos | id: ""}) == {:error, :texto_vacio}
      assert Necesidad.nueva(%{@datos | zona: " "}) == {:error, :texto_vacio}
    end
  end

  describe "estados" do
    test "flujo completo pendiente -> atendida" do
      {:ok, n} = Necesidad.nueva(@datos)
      assert {:ok, n} = Necesidad.cambiar_estado(n, :asignada)
      assert {:ok, n} = Necesidad.cambiar_estado(n, :en_atencion)
      assert {:ok, n} = Necesidad.cambiar_estado(n, :atendida)
      assert n.estado == :atendida
    end

    test "transición inválida" do
      {:ok, n} = Necesidad.nueva(@datos)
      assert Necesidad.cambiar_estado(n, :atendida) == {:error, :transicion_invalida}
    end

    test "no se puede cerrar dos veces" do
      {:ok, n} = Necesidad.nueva(@datos)
      {:ok, n} = Necesidad.cambiar_estado(n, :cancelada)
      assert Necesidad.cambiar_estado(n, :cancelada) == {:error, :necesidad_cerrada}
      assert Necesidad.cambiar_estado(n, :asignada) == {:error, :necesidad_cerrada}
    end
  end

  describe "registrar_asignacion/2" do
    test "la primera asignación pasa a :asignada y acumula" do
      {:ok, n} = Necesidad.nueva(@datos)
      assert {:ok, n} = Necesidad.registrar_asignacion(n, {"R001", "centro_acopio_1", 20})
      assert n.estado == :asignada
      assert n.cantidad_asignada == 20
      assert Necesidad.faltante(n) == 10
      refute Necesidad.cubierta?(n)

      assert {:ok, n} = Necesidad.registrar_asignacion(n, {"R002", "bodega", 10})
      assert n.cantidad_asignada == 30
      assert Necesidad.cubierta?(n)
      assert n.asignaciones == [{"R001", "centro_acopio_1", 20}, {"R002", "bodega", 10}]
    end

    test "no admite más de lo que falta" do
      {:ok, n} = Necesidad.nueva(@datos)
      assert Necesidad.registrar_asignacion(n, {"R001", "c", 31}) == {:error, :excede_requerido}
    end

    test "una necesidad atendida o cancelada no vuelve a consumir recursos" do
      {:ok, n} = Necesidad.nueva(@datos)
      {:ok, cancelada} = Necesidad.cambiar_estado(n, :cancelada)
      assert Necesidad.registrar_asignacion(cancelada, {"R001", "c", 1}) == {:error, :necesidad_cerrada}

      {:ok, n} = Necesidad.registrar_asignacion(n, {"R001", "c", 30})
      {:ok, n} = Necesidad.cambiar_estado(n, :en_atencion)
      {:ok, atendida} = Necesidad.cambiar_estado(n, :atendida)
      assert Necesidad.registrar_asignacion(atendida, {"R001", "c", 1}) == {:error, :necesidad_cerrada}
    end

    test "asignaciones mal formadas" do
      {:ok, n} = Necesidad.nueva(@datos)
      assert Necesidad.registrar_asignacion(n, {"R001", "c", 0}) == {:error, :asignacion_invalida}
      assert Necesidad.registrar_asignacion(n, {"R001", "c", -4}) == {:error, :asignacion_invalida}
      assert Necesidad.registrar_asignacion(n, :cualquier_cosa) == {:error, :asignacion_invalida}
    end
  end

  describe "prioridad (recursivas)" do
    test "insertar_por_prioridad mantiene el orden critica > alta > media > baja" do
      lista =
        []
        |> then(&Necesidad.insertar_por_prioridad(&1, nec("a", :baja)))
        |> then(&Necesidad.insertar_por_prioridad(&1, nec("b", :critica)))
        |> then(&Necesidad.insertar_por_prioridad(&1, nec("c", :media)))
        |> then(&Necesidad.insertar_por_prioridad(&1, nec("d", :alta)))

      assert Enum.map(lista, & &1.id) == ["b", "d", "c", "a"]
    end

    test "ordenar es estable: a igual prioridad respeta el orden de llegada" do
      entrada = [nec("1", :media), nec("2", :critica), nec("3", :media), nec("4", :critica), nec("5", :baja)]
      assert entrada |> Necesidad.ordenar() |> Enum.map(& &1.id) == ["2", "4", "1", "3", "5"]
    end

    test "ordenar lista vacía" do
      assert Necesidad.ordenar([]) == []
    end

    test "peso de cada prioridad" do
      assert Enum.map(Necesidad.prioridades(), &Necesidad.peso/1) == [0, 1, 2, 3]
    end
  end

  describe "filtrar/2" do
    setup do
      lista = [
        %Necesidad{id: "1", tipo: :agua, cantidad: 1, zona: "centro", prioridad: :critica, estado: :pendiente},
        %Necesidad{id: "2", tipo: :agua, cantidad: 1, zona: "norte", prioridad: :alta, estado: :asignada},
        %Necesidad{id: "3", tipo: :rescate, cantidad: 1, zona: "centro", prioridad: :alta, estado: :pendiente}
      ]

      {:ok, lista: lista}
    end

    test "por un criterio", %{lista: lista} do
      assert lista |> Necesidad.filtrar(zona: "centro") |> Enum.map(& &1.id) == ["1", "3"]
      assert lista |> Necesidad.filtrar(tipo: :rescate) |> Enum.map(& &1.id) == ["3"]
    end

    test "por varios criterios, con texto o átomos", %{lista: lista} do
      assert lista |> Necesidad.filtrar(zona: "centro", prioridad: "critica") |> Enum.map(& &1.id) == ["1"]
      assert lista |> Necesidad.filtrar(estado: :pendiente, prioridad: :alta) |> Enum.map(& &1.id) == ["3"]
    end

    test "sin filtros o con filtros desconocidos devuelve todo", %{lista: lista} do
      assert Necesidad.filtrar(lista, []) == lista
      assert Necesidad.filtrar(lista, color: "rojo") == lista
    end
  end
end
