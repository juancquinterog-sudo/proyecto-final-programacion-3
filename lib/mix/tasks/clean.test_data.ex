defmodule Mix.Tasks.Clean.TestData do
  use Mix.Task

  @shortdoc "Limpia los datos de prueba"

  @impl true
  def run(_args) do
    File.rm_rf!("tmp/test_data")
    Mix.shell().info("Datos de prueba limpiados.")
  end
end
