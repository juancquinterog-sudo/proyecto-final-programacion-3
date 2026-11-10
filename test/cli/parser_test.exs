defmodule Emergencias.Cli.ParserTest do
  use ExUnit.Case, async: true

  alias Emergencias.Cli.Parser

  describe "tokenizar/1" do
    test "separa por espacios" do
      assert Parser.tokenizar("a b   c") == {:ok, ["a", "b", "c"]}
      assert Parser.tokenizar("  a\tb\n") == {:ok, ["a", "b"]}
    end

    test "línea vacía" do
      assert Parser.tokenizar("") == {:ok, []}
      assert Parser.tokenizar("   ") == {:ok, []}
    end

    test "respeta comillas" do
      assert Parser.tokenizar(~s(msg 123 "Estoy bien, en el albergue norte")) ==
               {:ok, ["msg", "123", "Estoy bien, en el albergue norte"]}
    end

    test "comillas en medio de un token y token vacío" do
      assert Parser.tokenizar(~s(zona="zona norte" x)) == {:ok, ["zona=zona norte", "x"]}
      assert Parser.tokenizar(~s(a "" b)) == {:ok, ["a", "", "b"]}
    end

    test "comillas sin cerrar" do
      assert Parser.tokenizar(~s(a "b c)) == {:error, :comillas_sin_cerrar}
    end

    test "caracteres no ASCII" do
      assert Parser.tokenizar("report_person 1 Andrés") == {:ok, ["report_person", "1", "Andrés"]}
    end
  end

  describe "parsear/1" do
    test "argumentos posicionales" do
      assert Parser.parsear("connect laura 1234 coordinador centro") ==
               {:ok, {:connect, ["laura", "1234", "coordinador", "centro"], []}}
    end

    test "opciones clave=valor" do
      assert Parser.parsear("list_needs zona=centro prioridad=critica") ==
               {:ok, {:list_needs, [], [zona: "centro", prioridad: "critica"]}}
    end

    test "mezcla de argumentos y opciones" do
      assert Parser.parsear(~s(report_person 123 "Andrés" zona_norte localizada edad=30)) ==
               {:ok, {:report_person, ["123", "Andrés", "zona_norte", "localizada"], [edad: "30"]}}
    end

    test "un texto con = que no es una opción conocida queda como argumento" do
      assert Parser.parsear("register_need agua 30 critica centro a=b") ==
               {:ok, {:register_need, ["agua", "30", "critica", "centro", "a=b"], []}}
    end

    test "mensaje entre comillas" do
      assert Parser.parsear(~s(send_family_message 123 "Estoy bien, estoy en el albergue norte")) ==
               {:ok, {:send_family_message, ["123", "Estoy bien, estoy en el albergue norte"], []}}
    end

    test "el comando no distingue mayúsculas ni espacios sobrantes" do
      assert Parser.parsear("  SUMMARY  ") == {:ok, {:summary, [], []}}
    end

    test "errores" do
      assert Parser.parsear("") == {:error, :comando_vacio}
      assert Parser.parsear("   ") == {:error, :comando_vacio}
      assert Parser.parsear("bailar mucho") == {:error, :comando_desconocido}
      assert Parser.parsear(~s(summary "abierta)) == {:error, :comillas_sin_cerrar}
    end

    test "todos los comandos del enunciado se reconocen" do
      for comando <- Parser.comandos() do
        assert {:ok, {^comando, [], []}} = Parser.parsear(Atom.to_string(comando))
      end
    end
  end
end
