defmodule Emergencias do
  @moduledoc """
  Fachada del sistema distribuido de coordinación y gestión de emergencias
  (contexto: atención posterior a un terremoto).

  Punto de entrada único para la capa de presentación: recibe una sesión y una
  línea de comando, y devuelve `{:ok, mensaje}` o `{:error, razon}`.

  Arquitectura por capas (de arriba hacia abajo):

    * `Emergencias.Cli.*`          - interfaz de comandos (parser, shell, formato)
    * `Emergencias.Servicios.*`    - orquestación entre varios procesos
    * `Emergencias.Servidores.*`   - procesos con estado (GenServer)
    * `Emergencias.Procesos.*`     - procesos puros (spawn / send / receive)
    * `Emergencias.Dominio.*`      - funciones puras y estructuras de datos
    * `Emergencias.Persistencia.*` - archivos de texto plano
    * `Emergencias.Supervisores.*` - árbol de supervisión OTP
  """

  alias Emergencias.Cli.{Comandos, Parser, Sesion}

  @doc "Ejecuta una línea de comando en nombre de una sesión."
  @spec ejecutar(Sesion.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def ejecutar(%Sesion{} = _sesion, linea) when is_binary(linea) do
    # TODO: con {:ok, comando} <- Parser.parsear(linea), do: Comandos.ejecutar(sesion, comando)
    _ = {Parser, Comandos}
    {:error, :no_implementado}
  end
end
