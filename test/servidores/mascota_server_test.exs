defmodule Emergencias.Servidores.MascotaServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.MascotaServer
  alias Emergencias.Dominio.Mascota

  test "iniciar servidor de mascota" do
    mascota = %Mascota{
      id: "M01",
      nombre: "Firulais",
      especie: :perro,
      tipo: :perro,
      estado: :rescate,
      zona: "z101"
    }

    # Aceptamos tanto que inicie como que ya esté activo
    result = MascotaServer.start_link(mascota)
    assert match?({:ok, _pid}, result) or match?({:error, {:already_started, _pid}}, result)
  end
end
