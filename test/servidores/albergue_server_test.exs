defmodule Emergencias.Servidores.AlbergueServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.AlbergueServer
  alias Emergencias.Dominio.Albergue

  test "iniciar y probar llamadas al servidor de albergue" do
    albergue = %Albergue{
      codigo: "A99",
      nombre: "Refugio Norte",
      capacidad: 200,
      zona: "Z01"
    }

    case AlbergueServer.start_link(albergue) do
      {:ok, pid} ->
        assert Process.alive?(pid)
      {:error, {:already_started, pid}} ->
        assert Process.alive?(pid)
    end
  end
end
