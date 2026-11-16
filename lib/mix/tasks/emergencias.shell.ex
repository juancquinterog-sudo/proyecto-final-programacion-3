defmodule Mix.Tasks.Emergencias.Shell do
  @shortdoc "Inicia la consola interactiva del sistema de emergencias"
  @moduledoc "Uso: `mix emergencias.shell`"
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    Emergencias.Cli.Shell.iniciar()
  end
end
