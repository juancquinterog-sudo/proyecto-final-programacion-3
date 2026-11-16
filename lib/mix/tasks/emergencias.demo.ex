defmodule Mix.Tasks.Emergencias.Demo do
  @shortdoc "Demuestra el conflicto concurrente (30 + 25 litros sobre 50 disponibles)"
  @moduledoc """
  Escenario del PDF (sección flujo de ejemplo), para el VIDEO de demostración:

    1. Registra el recurso R001 (50 litros de agua) en centro_acopio_1.
    2. Registra dos necesidades (30 y 25 litros).
    3. Lanza las dos asignaciones EN PARALELO con `Task.Supervisor.async_stream_nolink`.
    4. Verifica: asignado <= 50 y existencias >= 0; una asignación se rechaza.
    5. Prueba de carga: 20 necesidades de 5 litros sobre 70 L -> exactamente 14 se confirman.
    6. Registra persona, mensaje, albergue, mascotas y muestra `summary`.

  Usa una carpeta de datos temporal (no toca `data/`). Uso: `mix emergencias.demo`
  """
  use Mix.Task

  alias Emergencias.Cli.{Comandos, Formato, Parser, Sesion}
  alias Emergencias.Servidores.{NecesidadServer, RecursoServer}

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")

    dir =
      Path.join(
        System.tmp_dir!(),
        "emergencias_demo_#{System.os_time(:microsecond)}"
      )

    File.mkdir_p!(dir)

    Application.put_env(:emergencias, :data_dir, dir)
    Mix.Task.run("app.start")

    titulo("1. Usuarios y recurso inicial")
    laura = conectar("connect laura 1234 coordinador centro")
    carlos = conectar("connect carlos 1234 coordinador centro")
    ejecutar(laura, "register_resource R001 agua 50 litros centro_acopio_1")

    titulo("2. Dos necesidades que, juntas (55 L), superan el inventario (50 L)")

    {:ok, necesidad1} =
      Emergencias.Servidores.NecesidadServer.registrar(%{
        tipo: "agua",
        cantidad: 30,
        prioridad: "critica",
        zona: "centro",
        descripcion: "Punto de atención sector 3"
      })

    {:ok, necesidad2} =
      Emergencias.Servidores.NecesidadServer.registrar(%{
        tipo: "agua",
        cantidad: 25,
        prioridad: "critica",
        zona: "centro",
        descripcion: "Punto de atención sector 5"
      })

    Mix.shell().info("Necesidad #{necesidad1.id} registrada: 30 litros.")
    Mix.shell().info("Necesidad #{necesidad2.id} registrada: 25 litros.")
    titulo("3. Las dos asignaciones se lanzan EN PARALELO")

    resultados =
      [
        {laura, "assign_resource #{necesidad1.id} agua 30"},
        {carlos, "assign_resource #{necesidad2.id} agua 25"}
      ]
      |> then(
        &Task.Supervisor.async_stream_nolink(
          Emergencias.TareaSupervisor,
          &1,
          fn {s, l} -> {l, correr(s, l)} end,
          timeout: 10_000
        )
      )
      |> Enum.map(fn {:ok, r} -> r end)

    Enum.each(resultados, fn {linea, r} -> mostrar(linea, r) end)

    {:ok, r001} = RecursoServer.consultar("R001")
    restante = Emergencias.Dominio.Recurso.total(r001)
    confirmadas = Enum.count(resultados, fn {_, r} -> match?({:ok, _, _}, r) end)
    asignado = 50 - restante

    Mix.shell().info(
      "\nConfirmadas: #{confirmadas} | asignado: #{asignado} L | restante: #{restante} L"
    )

    verificar!(
      asignado <= 50 and restante >= 0 and confirmadas == 1,
      "conflicto resuelto"
    )

    titulo("4. Prueba de carga: 20 solicitudes de 5 L sobre 70 L")

    # Dejar R001 exactamente con 20 litros
    {:ok, recurso_actual} = RecursoServer.consultar("R001")
    stock_actual = Emergencias.Dominio.Recurso.total(recurso_actual)

    if stock_actual > 20 do
      {:ok, _} =
        RecursoServer.salida(
          "R001",
          "centro_acopio_1",
          stock_actual - 20,
          %{referencia: "ajuste_prueba_carga"}
        )
    end

    # Registrar R002 con 50 litros
    ejecutar(laura, "register_resource R002 agua 50 litros centro_acopio_2")

    # Crear 20 necesidades de 5 litros
    ids =
      for _ <- 1..20 do
        {:ok, n} =
          NecesidadServer.registrar(%{
            tipo: "agua",
            cantidad: 5,
            prioridad: "alta",
            zona: "centro"
          })

        n.id
      end

    # Ejecutar las 20 asignaciones concurrentemente
    ok =
      Emergencias.TareaSupervisor
      |> Task.Supervisor.async_stream_nolink(
        ids,
        fn id ->
          Emergencias.Servicios.Asignador.asignar(id, "agua", 5, "demo")
        end,
        max_concurrency: 20,
        timeout: 20_000
      )
      |> Enum.count(fn {:ok, r} -> match?({:ok, _}, r) end)

    {:ok, r002} = RecursoServer.consultar("R002")
    {:ok, r001b} = RecursoServer.consultar("R001")

    stock_r002 = Emergencias.Dominio.Recurso.total(r002)
    stock_r001 = Emergencias.Dominio.Recurso.total(r001b)

    Mix.shell().info(
      "Confirmadas: #{ok} de 20 | stock R002: #{stock_r002} | stock R001: #{stock_r001}"
    )

    verificar!(
      ok == 14 and stock_r002 == 0 and stock_r001 == 0,
      "se confirman exactamente 14 (70 L / 5 L) y nunca hay stock negativo"
    )

    titulo("5. Albergue, persona, mensaje y mascotas")
    ejecutar(laura, ~s(register_shelter A01 "Albergue Norte" zona_norte 150))
    ejecutar(laura, "report_person 1090 Andres zona_norte localizada edad=30")
    ejecutar(laura, "register_entry A01 1090")
    ejecutar(laura, ~s(send_family_message 1090 "Estoy bien, estoy en el albergue norte"))
    ejecutar(laura, "list_family_messages 1090")

    ejecutar(
      laura,
      "report_pet lost perro Luna negra mediana zona_norte 3001112233 caracteristicas=collar,manchas"
    )

    ejecutar(
      laura,
      "report_pet found perro desconocido negra mediana zona_norte 3004445566 caracteristicas=collar"
    )

    ejecutar(laura, "match_pets")

    titulo("6. Resumen global")
    ejecutar(laura, "summary")
    ejecutar(laura, "critical_resources")
    Mix.shell().info("\nDatos persistidos en: #{dir}")
  end

  defp conectar(linea) do
    {:ok, sesion, mensaje} = correr(Sesion.anonima(), linea)
    Mix.shell().info("> #{linea}\n#{mensaje}")
    sesion
  end

  defp ejecutar(sesion, linea), do: mostrar(linea, correr(sesion, linea))

  defp correr(sesion, linea) do
    with {:ok, comando} <- Parser.parsear(linea), do: Comandos.ejecutar(sesion, comando)
  end

  defp mostrar(linea, {:ok, _, mensaje}), do: Mix.shell().info("> #{linea}\n#{mensaje}")

  defp mostrar(linea, {:error, razon}),
    do: Mix.shell().info("> #{linea}\n#{Formato.error(razon)}")

  defp titulo(texto), do: Mix.shell().info("\n=== #{texto} ===")

  defp verificar!(true, texto), do: Mix.shell().info("[OK] #{texto}")
  defp verificar!(false, texto), do: Mix.raise("[FALLO] #{texto}")
end
