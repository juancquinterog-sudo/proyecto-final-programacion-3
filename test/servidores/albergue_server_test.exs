defmodule Emergencias.Servidores.AlbergueServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.AlbergueServer
  alias Emergencias.Dominio.Albergue

  test "iniciar servidor de albergue" do
    albergue = %Albergue{
      codigo: "A01",
      nombre: "Coliseo",
      capacidad: 100,
      zona: "Zon1"
    }

    # AlbergueServer.start_link recibe el struct directamente según el error de tipado
    assert {:ok, _pid} = AlbergueServer.start_link(albergue)
  end
end
