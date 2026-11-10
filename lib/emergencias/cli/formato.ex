defmodule Emergencias.Cli.Formato do
  @moduledoc "Presentación: convierte structs y errores en texto legible (tablas simples). Funciones puras."

  @spec error(atom() | tuple()) :: String.t()
  def error(razon), do: "Error: #{inspect(razon)}"

  @spec tabla([String.t()], [[term()]]) :: String.t()
  def tabla(_encabezados, _filas), do: ""
end
