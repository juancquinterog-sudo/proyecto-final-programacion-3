defmodule Emergencias.Persistencia.AlmacenTest do
  # No async: todas las pruebas comparten la carpeta de datos de prueba.
  use ExUnit.Case, async: false

  alias Emergencias.Dominio.{PuntoAtencion, Sector, Usuario, Zona}
  alias Emergencias.Persistencia.Almacen

  setup do
    dir = Application.fetch_env!(:emergencias, :data_dir)
    File.rm_rf!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    :ok
  end

  defp usuario(i) do
    %Usuario{nombre_usuario: "user#{i}", hash_contrasena: "h#{i}", nombre_completo: "Usuario | #{i}", tipo: :ciudadano, zona: "centro"}
  end

  test "cargar sin archivo devuelve lista vacía" do
    assert Almacen.cargar(:usuarios) == {:ok, []}
  end

  test "entidad desconocida" do
    assert Almacen.cargar(:inventada) == {:error, :entidad_desconocida}
    assert Almacen.guardar(:inventada, []) == {:error, :entidad_desconocida}
  end

  test "guardar y cargar es ida y vuelta (round-trip)" do
    usuarios = Enum.map(1..3, &usuario/1)
    assert Almacen.guardar(:usuarios, usuarios) == :ok
    assert Almacen.cargar(:usuarios) == {:ok, usuarios}
  end

  test "guardar reemplaza el contenido anterior" do
    :ok = Almacen.guardar(:usuarios, [usuario(1), usuario(2)])
    :ok = Almacen.guardar(:usuarios, [usuario(3)])
    assert Almacen.cargar(:usuarios) == {:ok, [usuario(3)]}
  end

  test "agregar acumula registros" do
    :ok = Almacen.agregar(:usuarios, usuario(1))
    :ok = Almacen.agregar(:usuarios, usuario(2))
    assert Almacen.cargar(:usuarios) == {:ok, [usuario(1), usuario(2)]}
  end

  test "el archivo es texto plano legible" do
    :ok = Almacen.guardar(:usuarios, [usuario(1)])
    assert File.read!(Almacen.ruta(:usuarios)) == "user1|h1|Usuario \\| 1|ciudadano|centro\n"
  end

  test "las zonas guardan el árbol completo" do
    zona = %Zona{
      codigo: "centro",
      nombre: "Centro",
      nivel: :alto,
      personas_estimadas: 10,
      sectores: [%Sector{codigo: "s1", nombre: "S1", personas_estimadas: 5, puntos: [%PuntoAtencion{codigo: "p1", nombre: "P1", personas_estimadas: 2}]}]
    }

    :ok = Almacen.guardar(:zonas, [zona])
    assert Almacen.cargar(:zonas) == {:ok, [zona]}
  end

  test "escrituras concurrentes no corrompen el archivo" do
    resultados =
      1..100
      |> Task.async_stream(fn i -> Almacen.agregar(:usuarios, usuario(i)) end, max_concurrency: 50)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.all?(resultados, &(&1 == :ok))
    {:ok, cargados} = Almacen.cargar(:usuarios)
    assert length(cargados) == 100
    assert cargados |> Enum.map(& &1.nombre_usuario) |> Enum.uniq() |> length() == 100
  end
end
