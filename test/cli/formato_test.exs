defmodule Emergencias.Cli.FormatoTest do
  use ExUnit.Case, async: true

  alias Emergencias.Cli.Formato

  test "error/1 traduce los errores conocidos" do
    assert Formato.error(:credenciales_invalidas) =~ "contraseña"
    assert Formato.error(:sin_permiso) =~ "permiso"
    assert Formato.error({:uso, "summary"}) == "Uso: summary"
  end

  test "error/1 muestra los desconocidos con inspect" do
    assert Formato.error(:algo_raro) == "Error: :algo_raro"
  end

  test "tabla alinea las columnas" do
    esperado =
      Enum.join(
        ["id   | zona", "-----+-------", "N001 | centro", "N2   | x"],
        "\n"
      )

    assert Formato.tabla(["id", "zona"], [["N001", "centro"], ["N2", "x"]]) == esperado
  end

  test "tabla sin filas" do
    assert Formato.tabla(["id"], []) == "(sin resultados)"
  end
end
