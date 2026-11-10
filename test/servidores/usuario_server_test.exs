defmodule Emergencias.Servidores.UsuarioServerTest do
  # No async: usa el servidor global y el archivo usuarios.txt de pruebas.
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.Usuario
  alias Emergencias.Persistencia.Almacen
  alias Emergencias.Servidores.UsuarioServer

  defp nombre, do: "u#{System.unique_integer([:positive])}"

  test "connect registra automáticamente si no existe" do
    n = nombre()
    assert {:ok, %Usuario{nombre_usuario: ^n, tipo: :coordinador, zona: "centro"}, :registrado} =
             UsuarioServer.conectar(n, "1234", "coordinador", "centro")

    assert UsuarioServer.conectado?(n)
    assert n in UsuarioServer.listar_conectados()
  end

  test "la contraseña se guarda como hash y el usuario queda en el archivo" do
    n = nombre()
    {:ok, usuario, :registrado} = UsuarioServer.conectar(n, "secreta", "ciudadano", "norte")
    refute usuario.hash_contrasena == "secreta"

    {:ok, guardados} = Almacen.cargar(:usuarios)
    assert Enum.any?(guardados, fn u -> u.nombre_usuario == n and u.hash_contrasena == usuario.hash_contrasena end)
    refute File.read!(Almacen.ruta(:usuarios)) =~ "secreta"
  end

  test "usuario existente: valida la contraseña" do
    n = nombre()
    {:ok, _, :registrado} = UsuarioServer.conectar(n, "1234", "voluntario", "centro")
    :ok = UsuarioServer.desconectar(n)

    assert UsuarioServer.conectar(n, "mala", nil, nil) == {:error, :credenciales_invalidas}
    refute UsuarioServer.conectado?(n)

    assert {:ok, %Usuario{tipo: :voluntario}, :autenticado} = UsuarioServer.conectar(n, "1234", nil, nil)
    assert UsuarioServer.conectado?(n)
  end

  test "al reconectar se ignoran el tipo y la zona enviados" do
    n = nombre()
    {:ok, _, :registrado} = UsuarioServer.conectar(n, "1234", "ciudadano", "centro")
    assert {:ok, %Usuario{tipo: :ciudadano, zona: "centro"}, :autenticado} =
             UsuarioServer.conectar(n, "1234", "administrador", "otra")
  end

  test "registro con datos incompletos o inválidos" do
    assert UsuarioServer.conectar(nombre(), "1234", nil, nil) == {:error, :faltan_datos_registro}
    assert UsuarioServer.conectar(nombre(), "1234", "ciudadano", nil) == {:error, :faltan_datos_registro}
    assert UsuarioServer.conectar(nombre(), "1234", "jefe", "centro") == {:error, :tipo_usuario_invalido}
    assert UsuarioServer.conectar(nombre(), "1234", "ciudadano", "  ") == {:error, :zona_requerida}
    assert UsuarioServer.conectar("  ", "1234", "ciudadano", "centro") == {:error, :texto_vacio}
    assert UsuarioServer.conectar(nombre(), "", "ciudadano", "centro") == {:error, :texto_vacio}
  end

  test "un registro fallido no deja al usuario creado" do
    n = nombre()
    assert {:error, _} = UsuarioServer.conectar(n, "1234", "jefe", "centro")
    assert UsuarioServer.obtener(n) == {:error, :no_existe}
  end

  test "disconnect" do
    n = nombre()
    {:ok, _, _} = UsuarioServer.conectar(n, "1234", "ciudadano", "centro")
    assert UsuarioServer.desconectar(n) == :ok
    refute UsuarioServer.conectado?(n)
    assert UsuarioServer.desconectar(n) == {:error, :no_conectado}
  end

  test "obtener" do
    n = nombre()
    {:ok, _, _} = UsuarioServer.conectar(n, "1234", "ciudadano", "centro")
    assert {:ok, %Usuario{nombre_usuario: ^n}} = UsuarioServer.obtener(n)
    assert UsuarioServer.obtener("no_existe_#{n}") == {:error, :no_existe}
  end

  test "usuarios conectando a la vez: todos quedan registrados" do
    nombres = Enum.map(1..30, fn _ -> nombre() end)

    resultados =
      nombres
      |> Task.async_stream(fn n -> UsuarioServer.conectar(n, "1234", "ciudadano", "centro") end, max_concurrency: 30)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.all?(resultados, &match?({:ok, _, :registrado}, &1))
    assert Enum.all?(nombres, &UsuarioServer.conectado?/1)
  end

  test "supervisión: tras caerse el servidor, los usuarios se recuperan del archivo" do
    n = nombre()
    {:ok, _, :registrado} = UsuarioServer.conectar(n, "1234", "coordinador", "centro")

    viejo = Process.whereis(UsuarioServer)
    ref = Process.monitor(viejo)
    Process.exit(viejo, :kill)
    assert_receive {:DOWN, ^ref, :process, ^viejo, :killed}

    esperar_reinicio(viejo, 100)

    assert {:ok, %Usuario{nombre_usuario: ^n, tipo: :coordinador}} = UsuarioServer.obtener(n)
    # la sesión no se persiste: hay que volver a conectarse
    refute UsuarioServer.conectado?(n)
    assert {:ok, _, :autenticado} = UsuarioServer.conectar(n, "1234", nil, nil)
  end

  defp esperar_reinicio(_viejo, 0), do: flunk("el supervisor no reinició UsuarioServer")

  defp esperar_reinicio(viejo, intentos) do
    case Process.whereis(UsuarioServer) do
      nil -> reintentar(viejo, intentos)
      ^viejo -> reintentar(viejo, intentos)
      _nuevo -> :ok
    end
  end

  defp reintentar(viejo, intentos) do
    Process.sleep(20)
    esperar_reinicio(viejo, intentos - 1)
  end
end
