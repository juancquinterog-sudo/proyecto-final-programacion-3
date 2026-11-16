defmodule Emergencias.Cli.Shell do
  @moduledoc """
  Consola interactiva. El bucle `loop/1` es RECURSIVO de cola y lleva la
  `Sesion` como argumento (no hay estado mutable). Cada instancia es un
  usuario distinto: se pueden abrir varias en paralelo (multiusuario).

  La lógica de cada línea está en `procesar_linea/2` (sin entrada/salida), de
  modo que se puede probar sin teclado.
  """

  alias Emergencias.Cli.{Comandos, Formato, Parser, Sesion}

  @spec iniciar() :: :ok
  def iniciar do
    IO.puts("Sistema de Coordinación de Emergencias - escriba 'help' para ver los comandos")
    loop(Sesion.anonima())
  end

  @doc "Texto que se muestra antes de cada entrada."
  @spec prompt(Sesion.t()) :: String.t()
  def prompt(%Sesion{usuario: nil}), do: "> "
  def prompt(%Sesion{usuario: usuario, tipo: tipo}), do: "#{usuario} (#{tipo})> "

  @doc """
  Procesa una línea. Devuelve `{:continuar, sesion, texto}` o `{:salir, texto}`.
  """
  @spec procesar_linea(Sesion.t(), String.t()) ::
          {:continuar, Sesion.t(), String.t()} | {:salir, String.t()}
  def procesar_linea(%Sesion{} = sesion, linea) do
    case Parser.parsear(linea) do
      {:error, :comando_vacio} ->
        {:continuar, sesion, ""}

      {:error, razon} ->
        {:continuar, sesion, Formato.error(razon)}

      {:ok, {:exit, _, _} = comando} ->
        case Comandos.ejecutar(sesion, comando) do
          {:ok, _sesion, mensaje} -> {:salir, mensaje}
          {:error, razon} -> {:continuar, sesion, Formato.error(razon)}
        end

      {:ok, comando} ->
        case Comandos.ejecutar(sesion, comando) do
          {:ok, nueva, mensaje} -> {:continuar, nueva, mensaje}
          {:error, razon} -> {:continuar, sesion, Formato.error(razon)}
        end
    end
  end

  # Recursión de cola: la sesión viaja como argumento.
  defp loop(%Sesion{} = sesion) do
    entrada =
      case IO.gets(prompt(sesion)) do
        texto when is_binary(texto) -> texto
        # fin de entrada (Ctrl+Z / Ctrl+D) o error: se trata como `exit`
        _ -> "exit"
      end

    case procesar_linea(sesion, entrada) do
      {:continuar, nueva, texto} ->
        imprimir(texto)
        loop(nueva)

      {:salir, texto} ->
        imprimir(texto)
        :ok
    end
  end

  defp imprimir(""), do: :ok
  defp imprimir(texto), do: IO.puts(texto)
end
