defmodule Emergencias.Cli.Shell do
  @moduledoc """
  Consola interactiva. El bucle `loop/1` es RECURSIVO de cola y lleva la
  `Sesion` como argumento (no hay estado mutable). Cada instancia es un
  usuario distinto: se pueden abrir varias en paralelo (multiusuario).
  """

  alias Emergencias.Cli.Sesion

  @spec iniciar() :: :ok
  def iniciar do
    IO.puts("Sistema de Coordinación de Emergencias - escriba 'help' para ver los comandos")
    loop(Sesion.anonima())
  end

  # TODO: leer con IO.gets, Parser.parsear, Comandos.ejecutar, mostrar con Formato y volver a loop/1.
  # Terminar (sin llamar a loop) cuando el comando sea `exit`.
  defp loop(%Sesion{} = _sesion), do: :ok
end
