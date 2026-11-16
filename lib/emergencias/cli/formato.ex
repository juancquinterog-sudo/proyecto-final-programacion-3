defmodule Emergencias.Cli.Formato do
  @moduledoc "Presentación: convierte errores y listas en texto legible. Funciones puras."

  alias Emergencias.Dominio.{Albergue, Necesidad, Recurso, Zona}

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
    do:
      "Error: el usuario no existe; para registrarlo indica tipo y zona (connect usuario contraseña tipo zona)."

  def error(:tipo_usuario_invalido),
    do: "Error: tipo de usuario inválido (ciudadano, voluntario, coordinador o administrador)."

  def error(:zona_requerida), do: "Error: debes indicar la zona principal."
  def error(:texto_vacio), do: "Error: falta un dato obligatorio."
  def error(:cantidad_invalida), do: "Error: la cantidad debe ser un número entero válido."
  def error(:no_existe), do: "Error: no se encontró el registro solicitado."
  def error(:id_duplicado), do: "Error: ya existe un registro con ese código."
  def error(:sector_duplicado), do: "Error: la zona ya tiene un sector con ese código."
  def error(:sector_no_existe), do: "Error: el sector no existe en esa zona."
  def error(:punto_duplicado), do: "Error: ya existe un punto de atención con ese código."

  def error(:tipo_invalido),
    do:
      "Error: tipo inválido (agua, alimentos, medicamentos, primeros_auxilios, refugio, transporte, rescate u otra)."

  def error(:prioridad_invalida), do: "Error: prioridad inválida (critica, alta, media o baja)."
  def error(:nivel_invalido), do: "Error: nivel inválido (critico, alto, medio o bajo)."
  def error(:estado_invalido), do: "Error: estado inválido."
  def error(:necesidad_cerrada), do: "Error: la necesidad ya está cerrada (atendida o cancelada)."
  def error(:transicion_invalida), do: "Error: ese cambio de estado no es válido."
  def error(:excede_requerido), do: "Error: la cantidad excede lo que falta por cubrir."
  def error(:stock_insuficiente), do: "Error: no hay existencias suficientes; no se asignó nada."

  def error(:categoria_distinta),
    do: "Error: la categoría del recurso no coincide con el tipo de la necesidad."

  def error(:ubicacion_invalida), do: "Error: ubicación inválida."
  def error(:misma_ubicacion), do: "Error: el origen y el destino son iguales."
  def error(:sin_cupo), do: "Error: el albergue no tiene cupos disponibles."
  def error(:ya_ingresado), do: "Error: la persona ya está registrada en el albergue."
  def error(:no_esta_en_albergue), do: "Error: la persona no está en el albergue."
  def error(:ya_resuelta), do: "Error: el reporte ya fue resuelto."
  def error(:tipo_reporte_invalido), do: "Error: tipo de reporte inválido (lost/found)."
  def error(:tamano_invalido), do: "Error: tamaño inválido (pequena, mediana o grande)."

  def error(:tipos_incompatibles),
    do: "Error: se necesita un reporte 'perdida' y uno 'encontrada'."

  def error(otro), do: "Error: #{inspect(otro)}"

  @doc "Tabla de recursos con existencias por ubicación."
  def recursos(lista) do
    filas =
      Enum.map(lista, fn r ->
        ubic = r.existencias |> Enum.sort() |> Enum.map_join(", ", fn {u, c} -> "#{u}=#{c}" end)
        [r.codigo, r.nombre, r.categoria, Recurso.total(r), r.unidad, ubic]
      end)

    tabla(["codigo", "nombre", "categoria", "total", "unidad", "ubicaciones"], filas)
  end

  def personas(lista) do
    tabla(
      ["documento", "nombre", "zona", "estado", "edad"],
      Enum.map(lista, &[&1.documento, &1.nombre, &1.zona, &1.estado, &1.edad || "-"])
    )
  end

  def mensajes(lista) do
    tabla(
      ["id", "remitente", "estado", "mensaje"],
      Enum.map(lista, &[&1.id, &1.remitente, &1.estado, &1.contenido])
    )
  end

  def mascotas(lista) do
    tabla(
      ["id", "tipo", "especie", "nombre", "color", "tamano", "zona", "estado"],
      Enum.map(
        lista,
        &[
          &1.id,
          &1.tipo,
          &1.especie,
          &1.nombre || "-",
          &1.color || "-",
          &1.tamano || "-",
          &1.zona,
          &1.estado
        ]
      )
    )
  end

  def coincidencias([]), do: "(sin coincidencias por encima del umbral)"

  def coincidencias(lista) do
    tabla(
      ["perdida", "encontrada", "zona", "puntaje"],
      Enum.map(lista, fn {p, e, puntos} ->
        [p.id, e.id, p.zona, :erlang.float_to_binary(puntos, decimals: 2)]
      end)
    )
  end

  def albergues(lista) do
    tabla(
      ["codigo", "nombre", "zona", "ocupacion", "capacidad", "cupos", "%"],
      Enum.map(lista, fn a ->
        [
          a.codigo,
          a.nombre,
          a.zona,
          Albergue.ocupacion(a),
          a.capacidad,
          Albergue.cupos(a),
          Float.round(Albergue.porcentaje_ocupacion(a), 1)
        ]
      end)
    )
  end

  @doc "Resumen global (ver `Servicios.Resumen.resumen_global/0`)."
  def resumen(r) do
    por = fn mapa ->
      mapa |> Enum.sort() |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end) |> sin_vacio()
    end

    Enum.join(
      [
        "=== RESUMEN GLOBAL ===",
        "Zonas: #{r.zonas}",
        "Necesidades: #{r.necesidades.total} (pendientes: #{r.necesidades.pendientes}) | #{por.(r.necesidades.por_estado)}",
        "Personas: #{r.personas.total} | #{por.(r.personas.por_estado)}",
        "Mensajes: #{r.mensajes.total} (pendientes: #{r.mensajes.pendientes})",
        "Mascotas: #{r.mascotas.total} | #{por.(r.mascotas.por_estado)}",
        "Recursos restantes (críticos: #{r.recursos_criticos}):",
        tabla(
          ["codigo", "nombre", "total", "unidad"],
          Enum.map(r.recursos, &[&1.codigo, &1.nombre, &1.total, &1.unidad])
        ),
        "Albergues más ocupados:",
        albergues(r.albergues_mas_ocupados)
      ],
      "\n"
    )
  end

  defp sin_vacio(""), do: "-"
  defp sin_vacio(t), do: t

  @doc "Tabla de necesidades (ya ordenadas por quien llama)."
  @spec necesidades([Necesidad.t()]) :: String.t()
  def necesidades(lista) do
    filas =
      Enum.map(lista, fn n ->
        [
          n.id,
          n.tipo,
          n.cantidad,
          n.cantidad_asignada,
          n.prioridad,
          n.zona,
          n.estado,
          n.descripcion || ""
        ]
      end)

    tabla(["id", "tipo", "cant", "asig", "prioridad", "zona", "estado", "descripcion"], filas)
  end

  @doc "Estado general de una zona (ver `Servicios.Resumen.estado_zona/1`)."
  @spec estado_zona(map()) :: String.t()
  def estado_zona(%{zona: zona, estadisticas: est, necesidades: necesidades}) do
    pendientes = Enum.count(necesidades, &Necesidad.pendiente?/1)

    niveles =
      case est.por_nivel
           |> Enum.sort()
           |> Enum.map_join(", ", fn {nivel, n} -> "#{nivel}: #{n}" end) do
        "" -> "-"
        texto -> texto
      end

    cabecera = [
      "Zona #{zona.codigo} - #{zona.nombre} (nivel #{zona.nivel})",
      "Personas afectadas (total): #{est.total_afectados}",
      "Sectores: #{est.sectores} | Puntos de atención: #{est.puntos}",
      "Sectores por nivel: #{niveles}",
      "Necesidades: #{length(necesidades)} registradas, #{pendientes} pendientes"
    ]

    sectores =
      tabla(
        ["sector", "nombre", "nivel", "afectados"],
        Enum.map(zona.sectores, fn s -> [s.codigo, s.nombre, s.nivel, Zona.total_afectados(s)] end)
      )

    Enum.join(cabecera ++ ["", sectores], "\n")
  end

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
      [linea(encabezados, anchos), separador] ++
        Enum.map(filas, fn fila -> linea(fila, anchos) end)

    Enum.join(lineas, "\n")
  end

  defp linea(celdas, anchos) do
    celdas
    |> Enum.zip(anchos)
    |> Enum.map_join(" | ", fn {celda, ancho} -> String.pad_trailing(celda, ancho) end)
    |> String.trim_trailing()
  end
end
