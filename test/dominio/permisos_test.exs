defmodule Emergencias.Dominio.PermisosTest do
  use ExUnit.Case, async: true

  alias Emergencias.Dominio.Permisos

  test "ciudadano puede reportar pero no registrar recursos" do
    assert Permisos.permitido?(:ciudadano, :report_person)
    assert Permisos.permitido?(:ciudadano, :register_need)
    refute Permisos.permitido?(:ciudadano, :register_resource)
    assert Permisos.verificar(:ciudadano, :register_resource) == {:error, :sin_permiso}
  end

  test "voluntario puede registrar ingresos a albergue pero no asignar recursos" do
    assert Permisos.permitido?(:voluntario, :register_entry)
    assert Permisos.permitido?(:voluntario, :list_resources)
    refute Permisos.permitido?(:voluntario, :assign_resource)
  end

  test "coordinador puede asignar, transferir y ver el resumen" do
    for comando <- [:assign_resource, :transfer_resource, :summary, :register_zone] do
      assert Permisos.verificar(:coordinador, comando) == :ok
    end
  end

  test "administrador puede todos los comandos conocidos" do
    for comando <- Permisos.comandos_permitidos(:coordinador) do
      assert Permisos.permitido?(:administrador, comando)
    end
  end

  test "comando o rol desconocido no está permitido" do
    refute Permisos.permitido?(:administrador, :borrar_todo)
    refute Permisos.permitido?(:invitado, :summary)
  end

  test "comandos_permitidos crece con el rol" do
    assert length(Permisos.comandos_permitidos(:ciudadano)) <
             length(Permisos.comandos_permitidos(:voluntario))

    assert length(Permisos.comandos_permitidos(:voluntario)) <
             length(Permisos.comandos_permitidos(:coordinador))
  end
end
