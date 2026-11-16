defmodule Emergencias.Servidores.PersonaMascotaServerTest do
  use ExUnit.Case, async: false

  alias Emergencias.Servidores.{MascotaServer, PersonaServer}

  defp doc, do: "D#{System.unique_integer([:positive])}"

  describe "PersonaServer" do
    test "reportar, buscar y rechazar duplicados" do
      d = doc()

      assert {:ok, p} =
               PersonaServer.reportar(%{
                 documento: d,
                 nombre: "Andrés Ruiz",
                 zona: "norte",
                 estado: "localizada",
                 edad: "30"
               })

      assert p.estado == :localizada and p.edad == 30

      assert {:error, :id_duplicado} =
               PersonaServer.reportar(%{documento: d, nombre: "X", zona: "norte"})

      assert [%{documento: ^d}] = PersonaServer.buscar(documento: d)
      assert Enum.any?(PersonaServer.buscar(nombre: "andrés"), &(&1.documento == d))

      assert {:error, :texto_vacio} =
               PersonaServer.reportar(%{documento: "", nombre: "X", zona: "z"})

      assert {:error, :estado_invalido} =
               PersonaServer.reportar(%{
                 documento: doc(),
                 nombre: "X",
                 zona: "z",
                 estado: "volando"
               })
    end

    test "cambios de estado válidos con historial, inválidos rechazados" do
      d = doc()
      {:ok, _} = PersonaServer.reportar(%{documento: d, nombre: "Ana", zona: "z"})
      assert {:ok, p} = PersonaServer.cambiar_estado(d, :localizada, "laura")
      assert length(p.historial) == 2
      assert {:error, _} = PersonaServer.cambiar_estado(d, :sin_informacion, "laura")

      assert {:ok, %{estado: :reunificada}} =
               PersonaServer.cambiar_estado(d, :reunificada, "laura")

      assert {:error, _} = PersonaServer.cambiar_estado(d, :localizada, "laura")
      assert {:error, :no_existe} = PersonaServer.cambiar_estado("NOPE", :localizada, "x")
    end

    test "mensajes: enviar, listar, marcar" do
      d = doc()
      {:ok, _} = PersonaServer.reportar(%{documento: d, nombre: "Andrés", zona: "z"})

      assert {:ok, m} =
               PersonaServer.enviar_mensaje(%{
                 destinatario: d,
                 remitente: "mama",
                 contenido: "¿Estás bien?"
               })

      assert m.estado == :pendiente
      assert [%{id: id}] = PersonaServer.listar_mensajes(d)
      assert {:ok, %{estado: :entregado}} = PersonaServer.marcar_mensaje(id, :entregado)
      assert {:error, :no_existe} = PersonaServer.marcar_mensaje("MSG999999", :entregado)

      assert {:error, :no_existe} =
               PersonaServer.enviar_mensaje(%{
                 destinatario: "NOPE",
                 remitente: "x",
                 contenido: "y"
               })

      assert {:error, :texto_vacio} =
               PersonaServer.enviar_mensaje(%{destinatario: d, remitente: "x", contenido: ""})

      assert %{personas: [_ | _], mensajes: [_ | _]} = PersonaServer.todo()
    end
  end

  describe "MascotaServer" do
    defp reporte(tipo, zona, extra \\ %{}) do
      Map.merge(
        %{
          tipo: tipo,
          especie: "gato",
          nombre: "-",
          color: "gris",
          tamano: "pequena",
          zona: zona,
          contacto: "3000000"
        },
        extra
      )
    end

    test "reportar valida datos" do
      assert {:error, :tipo_reporte_invalido} = MascotaServer.reportar(reporte("otra", "z"))

      assert {:error, :tamano_invalido} =
               MascotaServer.reportar(reporte("lost", "z", %{tamano: "gigante"}))

      assert {:error, :texto_vacio} = MascotaServer.reportar(reporte("lost", "z", %{especie: ""}))
    end

    test "coincidencia y cierre de ambos reportes (sin resolver dos veces)" do
      zona = "zona_#{System.unique_integer([:positive])}"

      {:ok, p} =
        MascotaServer.reportar(reporte("lost", zona, %{caracteristicas: "collar,orejas largas"}))

      {:ok, e} = MascotaServer.reportar(reporte("found", zona, %{caracteristicas: "collar"}))

      {:ok, otra} =
        MascotaServer.reportar(
          reporte("found", "lejos", %{especie: "perro", color: "negro", tamano: "grande"})
        )

      coincidencias = MascotaServer.buscar_coincidencias()

      assert {_, _, puntaje} =
               Enum.find(coincidencias, fn {a, b, _} -> a.id == p.id and b.id == e.id end)

      assert puntaje >= 0.6
      refute Enum.any?(coincidencias, fn {_, b, _} -> b.id == otra.id end)
      assert [%{estado: :posible_coincidencia}] = MascotaServer.listar(zona: zona, tipo: :perdida)

      assert {:ok, {%{estado: :resuelta}, %{estado: :resuelta}}} =
               MascotaServer.confirmar_coincidencia(p.id, e.id)

      assert {:error, :ya_resuelta} = MascotaServer.confirmar_coincidencia(p.id, e.id)
      assert {:error, :no_existe} = MascotaServer.confirmar_coincidencia("M_NOPE", e.id)

      assert {:error, :tipos_incompatibles} =
               MascotaServer.confirmar_coincidencia(otra.id, otra.id)

      assert [] = MascotaServer.listar(zona: zona, estado: :activa)
      assert [_, _] = MascotaServer.listar(zona: zona, especie: "GATO", estado: :resuelta)
    end
  end
end
