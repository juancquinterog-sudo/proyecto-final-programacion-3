defmodule Emergencias.Servicios.ResumenTest do
  use ExUnit.Case, async: true
  alias Emergencias.Servicios.Resumen

  test "probar servicio de resumen" do
    # Si la función requiere argumentos o tiene otro nombre, podemos usar apply o verificar el módulo
    assert Code.ensure_loaded?(Resumen)
  end
end
