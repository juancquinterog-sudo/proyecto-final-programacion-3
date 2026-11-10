defmodule Emergencias.Cli.ShellTest do
  use ExUnit.Case, async: false

  alias Emergencias.Cli.{Shell, Sesion}

  defp nombre, do: "u#{System.unique_integer([:positive])}"

  test "líneas vacías se ignoran" do
    sesion = Sesion.anonima()
    assert Shell.procesar_linea(sesion, "   \n") == {:continuar, sesion, ""}
  end

  test "comando desconocido y comillas sin cerrar" do
    sesion = Sesion.anonima()
    assert {:continuar, ^sesion, texto} = Shell.procesar_linea(sesion, "bailar\n")
    assert texto =~ "desconocido"
    assert {:continuar, ^sesion, texto} = Shell.procesar_linea(sesion, ~s(summary "abierta\n))
    assert texto =~ "comillas"
  end

  test "sesión completa: connect, help, comando sin permiso, disconnect, exit" do
    n = nombre()
    {:continuar, sesion, texto} = Shell.procesar_linea(Sesion.anonima(), "connect #{n} 1234 ciudadano norte\n")
    assert texto =~ "registrado"
    assert %Sesion{usuario: ^n, tipo: :ciudadano, zona: "norte"} = sesion
    assert Shell.prompt(sesion) == "#{n} (ciudadano)> "

    assert {:continuar, ^sesion, ayuda} = Shell.procesar_linea(sesion, "help")
    assert ayuda =~ "report_person"

    assert {:continuar, ^sesion, denegado} = Shell.procesar_linea(sesion, "register_zone z1 Zona critico")
    assert denegado =~ "permiso"

    assert {:continuar, %Sesion{usuario: nil}, _} = Shell.procesar_linea(sesion, "disconnect")
    assert {:salir, "Hasta luego."} = Shell.procesar_linea(Sesion.anonima(), "exit")
  end

  test "errores de credenciales se muestran como texto" do
    n = nombre()
    {:continuar, _, _} = Shell.procesar_linea(Sesion.anonima(), "connect #{n} 1234 ciudadano norte")
    assert {:continuar, _, texto} = Shell.procesar_linea(Sesion.anonima(), "connect #{n} otra")
    assert texto =~ "contraseña"
  end

  test "prompt de una sesión anónima" do
    assert Shell.prompt(Sesion.anonima()) == "> "
  end
end
