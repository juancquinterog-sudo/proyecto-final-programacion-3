defmodule Emergencias.Servidores.MascotaServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.MascotaServer
  alias Emergencias.Dominio.Mascota

  test "iniciar y probar llamadas al servidor de mascota" do
    mascota = %Mascota{
      id: "M99",
      nombre: "Manchas",
      especie: :perro,
      tipo: :perro,
      estado: :rescate,
      zona: "z101"
    }

    case MascotaServer.start_link(mascota) do
      {:ok, pid} ->
        assert Process.alive?(pid)
      {:error, {:already_started, pid}} ->
        assert Process.alive?(pid)
    end
  end
end
