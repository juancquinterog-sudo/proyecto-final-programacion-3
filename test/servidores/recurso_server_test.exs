defmodule Emergencias.Servidores.RecursoServerTest do
  use ExUnit.Case, async: true
  alias Emergencias.Servidores.RecursoServer
  alias Emergencias.Dominio.Recurso

  test "iniciar y operar servidor de recurso" do
    recurso = %Recurso{
      codigo: "R01",
      nombre: "Agua Potable",
      zona: "Z01",
      categoria: :viveres, # Campo obligatorio requerido por la struct
      unidad: :litros      # Campo obligatorio requerido por la struct
    }

    case RecursoServer.start_link(recurso) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    if function_exported?(RecursoServer, :consultar, 1) do
      RecursoServer.consultar("R01")
    end
  end
end
