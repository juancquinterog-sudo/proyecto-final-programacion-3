defmodule Emergencias.Procesos.BitacoraTest do
  use ExUnit.Case, async: false

  alias Emergencias.Procesos.Bitacora

  test "registra y consulta la actividad de un usuario con paso de mensajes" do
    usuario = "bit#{System.unique_integer([:positive])}"
    Bitacora.registrar(usuario, :register_need, :ok)
    Bitacora.registrar(usuario, :assign_resource, {:error, :stock_insuficiente})
    Bitacora.registrar("otro", :summary, :ok)

    assert [%{comando: :assign_resource}, %{comando: :register_need}] =
             Bitacora.consultar(usuario)

    assert [] = Bitacora.consultar("nadie")

    assert File.read!(Path.join(Application.get_env(:emergencias, :data_dir), "actividad.log")) =~
             usuario
  end
end
