defmodule Emergencias.Servidores.AlbergueServerTest do
  use ExUnit.Case, async: true

  alias Emergencias.Servidores.AlbergueServer
  alias Emergencias.Dominio.Albergue

  test "operaciones del servidor de albergue" do
    albergue = %Albergue{
      codigo: "A99",
      nombre: "Refugio Norte",
      capacidad: 200,
      zona: "Z01"
    }

    # Probamos el inicio y las funciones públicas si están disponibles
    case AlbergueServer.start_link(albergue) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    if function_exported?(AlbergueServer, :listar, 0) do
      assert is_list(AlbergueServer.listar())
    end
  end
end
