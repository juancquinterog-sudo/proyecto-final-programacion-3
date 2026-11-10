defmodule Emergencias.Dominio.UsuarioTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Usuario

  @datos %{nombre_usuario: "laura", contrasena: "1234", tipo: "coordinador", zona: "centro"}

  test "nuevo/1 crea el usuario con la contraseña como hash" do
    assert {:ok, %Usuario{} = u} = Usuario.nuevo(@datos)
    assert u.nombre_usuario == "laura"
    assert u.tipo == :coordinador
    assert u.zona == "centro"
    assert u.nombre_completo == "laura"
    refute u.hash_contrasena == "1234"
    assert String.length(u.hash_contrasena) == 64
  end

  test "nuevo/1 valida los campos" do
    assert Usuario.nuevo(%{@datos | nombre_usuario: " "}) == {:error, :texto_vacio}
    assert Usuario.nuevo(%{@datos | contrasena: ""}) == {:error, :texto_vacio}
    assert Usuario.nuevo(%{@datos | tipo: "jefe"}) == {:error, :tipo_usuario_invalido}
  end

  test "autenticar/2 valida la contraseña" do
    {:ok, u} = Usuario.nuevo(@datos)
    assert Usuario.autenticar(u, "1234") == :ok
    assert Usuario.autenticar(u, "otra") == {:error, :credenciales_invalidas}
  end
end
