defmodule Mix.Tasks.Emergencias.Demo do
  @shortdoc "Demuestra el conflicto concurrente (30 + 25 litros sobre 50 disponibles)"
  @moduledoc """
  Escenario del PDF (sección flujo de ejemplo), para el VIDEO de demostración:

    1. Registra el recurso R001 (50 litros de agua) en centro_acopio_1.
    2. Registra dos necesidades (30 y 25 litros).
    3. Lanza las dos asignaciones EN PARALELO con `Task.Supervisor.async_stream`.
    4. Verifica: asignado <= 50 y existencias >= 0; una asignación se rechaza.
    5. Registra persona, mensaje, mascotas y muestra `summary`.

  Uso: `mix emergencias.demo`
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    # TODO: implementar el escenario descrito arriba.
    Mix.shell().info("Demo pendiente de implementar")
  end
end
