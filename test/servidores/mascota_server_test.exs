defmodule Emergencias.Servidores.MascotaServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.MascotaServer
  alias Emergencias.Dominio.Mascota

  test "operaciones del servidor de mascota" do
    mascota = %Mascota{
      id: "M99",
      nombre: "Manchas",
      especie: :perro,
      tipo: :perro,
      estado: :rescate,
      zona: "z101"
    }

    case MascotaServer.start_link(mascota) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    if function_exported?(MascotaServer, :listar, 0) do
      assert is_list(MascotaServer.listar())
    end
  end
end
