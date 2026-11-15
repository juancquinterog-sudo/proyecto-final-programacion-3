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
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    if function_exported?(PersonaServer, :consultar, 1) do
      PersonaServer.consultar("P01")
    end
  end
end
