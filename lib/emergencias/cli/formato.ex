defmodule Emergencias.Cli.Formato do
  @moduledoc "Presentación: convierte errores y listas en texto legible. Funciones puras."

  @doc "Mensaje legible para un error. Los desconocidos se muestran con `inspect/1`."
  @spec error(term()) :: String.t()
  def error({:uso, uso}), do: "Uso: #{uso}"
  def error({:persistencia, razon}), do: "Error al guardar los datos: #{inspect(razon)}"
  def error(:credenciales_invalidas), do: "Error: usuario o contraseña incorrectos."
  def error(:sin_permiso), do: "Error: no tienes permiso para ejecutar este comando."

  def error(:no_conectado),
    do: "Error: primero debes conectarte (connect usuario contraseña [tipo zona])."

  def error(:ya_conectado), do: "Error: ya hay una sesión iniciada; usa disconnect primero."
  def error(:comando_desconocido), do: "Error: comando desconocido. Escribe 'help'."
  def error(:comillas_sin_cerrar), do: "Error: hay comillas sin cerrar."
  def error(:no_implementado), do: "Este comando aún no está disponible."

  def error(:faltan_datos_registro),
    do: "Error: el usuario no existe; para registrarlo indica tipo y zona (connect usuario contraseña tipo zona)."

  def error(:tipo_usuario_invalido),
    do: "Error: tipo de usuario inválido (ciudadano, voluntario, coordinador o administrador)."

  def error(:zona_requerida), do: "Error: debes indicar la zona principal."
  def error(:texto_vacio), do: "Error: falta un dato obligatorio."
  def error(:cantidad_invalida), do: "Error: la cantidad debe ser un número entero válido."
  def error(otro), do: "Error: #{inspect(otro)}"

  @doc """
  Tabla de texto con columnas alineadas.

      id   | zona
      -----+-------
      N001 | centro
  """
  @spec tabla([String.t()], [[term()]]) :: String.t()
  def tabla(_encabezados, []), do: "(sin resultados)"

  def tabla(encabezados, filas) do
    filas = Enum.map(filas, fn fila -> Enum.map(fila, &to_string/1) end)
    todas = [encabezados | filas]

    anchos =
      Enum.zip_with(todas, fn columna -> columna |> Enum.map(&String.length/1) |> Enum.max() end)

    separador = Enum.map_join(anchos, "-+-", fn ancho -> String.duplicate("-", ancho) end)

    lineas =
      [linea(encabezados, anchos), separador] ++ Enum.map(filas, fn fila -> linea(fila, anchos) end)

    Enum.join(lineas, "\n")
  end

  defp linea(celdas, anchos) do
    celdas
    |> Enum.zip(anchos)
    |> Enum.map_join(" | ", fn {celda, ancho} -> String.pad_trailing(celda, ancho) end)
    |> String.trim_trailing()
  end
end
