defmodule Emergencias.Cli.ComandosTest do
  use ExUnit.Case, async: false

  alias Emergencias.Cli.{Comandos, Sesion}
  alias Emergencias.Servidores.UsuarioServer

  defp nombre, do: "u#{System.unique_integer([:positive])}"

  defp conectar(tipo \\ "ciudadano") do
    n = nombre()

    {:ok, sesion, _} =
      Comandos.ejecutar(Sesion.anonima(), {:connect, [n, "1234", tipo, "centro"], []})

    {n, sesion}
  end

  test "connect registra automáticamente y abre la sesión" do
    n = nombre()

    assert {:ok, %Sesion{usuario: ^n, tipo: :coordinador, zona: "centro"}, mensaje} =
             Comandos.ejecutar(
               Sesion.anonima(),
               {:connect, [n, "1234", "coordinador", "centro"], []}
             )

    assert mensaje =~ "registrado"
  end

  test "connect con usuario existente valida la contraseña" do
    {n, _sesion} = conectar()

    assert Comandos.ejecutar(Sesion.anonima(), {:connect, [n, "mala"], []}) ==
             {:error, :credenciales_invalidas}

    assert {:ok, %Sesion{usuario: ^n}, mensaje} =
             Comandos.ejecutar(Sesion.anonima(), {:connect, [n, "1234"], []})

    assert mensaje =~ "de nuevo"
  end

  test "connect de un usuario nuevo sin tipo y zona" do
    assert Comandos.ejecutar(Sesion.anonima(), {:connect, [nombre(), "1234"], []}) ==
             {:error, :faltan_datos_registro}
  end

  test "connect con tipo inválido" do
    assert Comandos.ejecutar(
             Sesion.anonima(),
             {:connect, [nombre(), "1234", "jefe", "centro"], []}
           ) ==
             {:error, :tipo_usuario_invalido}
  end

  test "connect sin argumentos muestra el uso" do
    assert {:error, {:uso, uso}} =
             Comandos.ejecutar(Sesion.anonima(), {:connect, ["solo_usuario"], []})

    assert uso =~ "connect"
  end

  test "con una sesión abierta no se puede volver a hacer connect" do
    {_n, sesion} = conectar()
    assert Comandos.ejecutar(sesion, {:connect, ["otro", "1234"], []}) == {:error, :ya_conectado}
  end

  test "sin sesión solo se permiten connect, help y exit" do
    assert Comandos.ejecutar(Sesion.anonima(), {:list_needs, [], []}) == {:error, :no_conectado}
    assert Comandos.ejecutar(Sesion.anonima(), {:disconnect, [], []}) == {:error, :no_conectado}
    assert {:ok, _, _} = Comandos.ejecutar(Sesion.anonima(), {:help, [], []})
  end

  test "los permisos dependen del tipo de usuario" do
    {_n, ciudadano} = conectar("ciudadano")
    assert Comandos.ejecutar(ciudadano, {:register_zone, [], []}) == {:error, :sin_permiso}
    assert Comandos.ejecutar(ciudadano, {:summary, [], []}) == {:error, :sin_permiso}

    {_n, coordinador} = conectar("coordinador")
    # permitido para el coordinador
    assert {:ok, _, _} = Comandos.ejecutar(coordinador, {:summary, [], []})
    # permitido y con argumentos faltantes: muestra el uso
    assert {:error, {:uso, _}} = Comandos.ejecutar(coordinador, {:register_zone, [], []})
  end

  test "disconnect cierra la sesión" do
    {n, sesion} = conectar()
    assert UsuarioServer.conectado?(n)

    assert {:ok, %Sesion{usuario: nil, tipo: nil}, mensaje} =
             Comandos.ejecutar(sesion, {:disconnect, [], []})

    assert mensaje =~ n
    refute UsuarioServer.conectado?(n)
  end

  test "exit cierra la sesión si había una" do
    {n, sesion} = conectar()
    assert {:ok, %Sesion{usuario: nil}, _} = Comandos.ejecutar(sesion, {:exit, [], []})
    refute UsuarioServer.conectado?(n)
  end

  test "help muestra solo los comandos permitidos" do
    {:ok, _, anonimo} = Comandos.ejecutar(Sesion.anonima(), {:help, [], []})
    assert anonimo =~ "connect"
    refute anonimo =~ "register_zone"

    {_, ciudadano} = conectar("ciudadano")
    {:ok, _, texto_ciudadano} = Comandos.ejecutar(ciudadano, {:help, [], []})
    assert texto_ciudadano =~ "report_person"
    refute texto_ciudadano =~ "register_zone"

    {_, coordinador} = conectar("coordinador")
    {:ok, _, texto_coordinador} = Comandos.ejecutar(coordinador, {:help, [], []})
    assert texto_coordinador =~ "register_zone"
    assert texto_coordinador =~ "assign_resource"
  end

  test "todo comando tiene texto de uso" do
    for comando <- Emergencias.Cli.Parser.comandos() do
      assert is_binary(Comandos.uso(comando))
    end
  end
end
