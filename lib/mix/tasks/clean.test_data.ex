defmodule Mix.Tasks.Clean.TestData do
  use Mix.Task

  @shortdoc "Limpia la carpeta de datos de prueba temporal"

  def run(_args) do
    dir = "tmp/test_data"

    case File.rm_rf(dir) do
      {:ok, _files} ->
        IO.puts("Carpeta de pruebas #{dir} limpiada exitosamente.")
      {:error, reason, file} ->
        IO.puts("No se pudo limpiar completamente #{file}: #{reason} (continuando de todos modos).")
    end
  end
end
