defmodule Emergencias.Servidores.PersonaServerTest do
  use ExUnit.Case, async: true
  alias Emergencias.Servidores.PersonaServer
  alias Emergencias.Dominio.Persona

  test "iniciar y operar servidor de persona" do
    persona = %Persona{
      id: "P01",
      nombre: "Ana Gómez",
      documento: "12345678",
      zona: "Z01",
      estado: :activo
    }

    case PersonaServer.start_link(persona) do
      {:ok, pid} -> assert Process.alive?(pid)
      {:error, {:already_started, pid}} -> assert Process.alive?(pid)
    end
  end
end
