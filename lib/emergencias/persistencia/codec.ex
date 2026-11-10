defmodule Emergencias.Persistencia.Codec do
  @moduledoc """
  Conversión struct <-> línea de texto plano para cada entidad. Mantiene el
  dominio puro: los structs no saben nada de archivos. Módulo PURO (sin I/O).

  ## Formato
  Un registro por línea, campos separados por `|`. Dentro de un campo, las
  listas se separan con `;` y los pares/tuplas con `:`. Para que ningún dato
  rompa el formato, cada valor "hoja" se escapa:

  | carácter | se guarda como |
  |----------|----------------|
  | `\\`     | `\\\\`         |
  | `|`      | `\\|`          |
  | `;`      | `\;`          |
  | `:`      | `\\:`          |
  | salto    | `\\n`          |

  Como todo separador queda escapado dentro de los valores, `dividir/2` puede
  partir por cualquier nivel sin ambigüedad.

  ## Zonas
  El árbol zona -> sectores -> puntos se guarda en varias líneas con prefijo:

      Z|codigo|nombre|nivel|personas
      S|zona|codigo|nombre|nivel|personas
      P|zona|sector|codigo|nombre|personas

  ## Nota
  Los átomos (estados, tipos) se leen con `String.to_atom/1`: el archivo es
  local y escrito por el propio sistema. El historial de movimientos de un
  recurso NO va en `recursos.txt` sino en `movimientos.txt`.
  """

  alias Emergencias.Dominio.{
    Albergue,
    Mascota,
    Mensaje,
    Movimiento,
    Necesidad,
    Persona,
    PuntoAtencion,
    Recurso,
    Sector,
    Usuario,
    Zona
  }

  ## ------------------------------------------------------------------
  ## struct -> texto
  ## ------------------------------------------------------------------

  @doc "Devuelve las líneas de un registro (una sola, salvo las zonas)."
  @spec a_lineas(struct()) :: [String.t()]
  def a_lineas(%Zona{} = zona) do
    cabecera = unir(["Z", txt(zona.codigo), txt(zona.nombre), atm(zona.nivel), ent(zona.personas_estimadas)])

    resto =
      Enum.flat_map(zona.sectores, fn sector ->
        linea_sector =
          unir([
            "S",
            txt(zona.codigo),
            txt(sector.codigo),
            txt(sector.nombre),
            atm(sector.nivel),
            ent(sector.personas_estimadas)
          ])

        lineas_puntos =
          Enum.map(sector.puntos, fn punto ->
            unir([
              "P",
              txt(zona.codigo),
              txt(sector.codigo),
              txt(punto.codigo),
              txt(punto.nombre),
              ent(punto.personas_estimadas)
            ])
          end)

        [linea_sector | lineas_puntos]
      end)

    [cabecera | resto]
  end

  def a_lineas(registro), do: [a_linea(registro)]

  @doc "Línea de un registro de una sola línea (todo excepto `Zona`)."
  @spec a_linea(struct()) :: String.t()
  def a_linea(%Usuario{} = u) do
    unir([txt(u.nombre_usuario), txt(u.hash_contrasena), txt(u.nombre_completo), atm(u.tipo), txt(u.zona)])
  end

  def a_linea(%Necesidad{} = n) do
    unir([
      txt(n.id),
      atm(n.tipo),
      txt(n.descripcion),
      ent(n.cantidad),
      ent(n.cantidad_asignada),
      txt(n.zona),
      atm(n.prioridad),
      txt(n.reportado_por),
      fch(n.creada_en),
      atm(n.estado),
      Enum.map_join(n.asignaciones, ";", fn {recurso, ubicacion, cantidad} ->
        Enum.join([txt(recurso), txt(ubicacion), ent(cantidad)], ":")
      end)
    ])
  end

  def a_linea(%Recurso{} = r) do
    unir([
      txt(r.codigo),
      txt(r.nombre),
      atm(r.categoria),
      txt(r.unidad),
      txt(r.zona),
      r.existencias
      |> Enum.sort()
      |> Enum.map_join(";", fn {ubicacion, cantidad} -> txt(ubicacion) <> ":" <> ent(cantidad) end)
    ])
  end

  def a_linea(%Movimiento{} = m) do
    unir([
      txt(m.codigo_recurso),
      atm(m.tipo),
      ent(m.cantidad),
      txt(m.ubicacion),
      txt(m.referencia),
      txt(m.usuario),
      fch(m.fecha)
    ])
  end

  def a_linea(%Persona{} = p) do
    unir([
      txt(p.id),
      txt(p.documento),
      txt(p.nombre),
      ent(p.edad),
      txt(p.zona),
      atm(p.estado),
      txt(p.albergue),
      Enum.map_join(p.historial, ";", fn {estado, fecha, usuario} ->
        Enum.join([atm(estado), fch(fecha), txt(usuario)], ":")
      end)
    ])
  end

  def a_linea(%Mensaje{} = m) do
    unir([txt(m.id), txt(m.destinatario), txt(m.remitente), txt(m.contenido), fch(m.fecha), atm(m.estado)])
  end

  def a_linea(%Mascota{} = m) do
    unir([
      txt(m.id),
      atm(m.tipo),
      txt(m.especie),
      txt(m.nombre),
      txt(m.color),
      atm(m.tamano),
      m.caracteristicas |> MapSet.to_list() |> Enum.sort() |> Enum.map_join(";", &txt/1),
      txt(m.zona),
      txt(m.contacto),
      txt(m.pareja_id),
      atm(m.estado)
    ])
  end

  def a_linea(%Albergue{} = a) do
    unir([
      txt(a.codigo),
      txt(a.nombre),
      txt(a.zona),
      ent(a.capacidad),
      a.ocupantes |> MapSet.to_list() |> Enum.sort() |> Enum.map_join(";", &txt/1)
    ])
  end

  ## ------------------------------------------------------------------
  ## texto -> struct
  ## ------------------------------------------------------------------

  @doc """
  Decodifica una línea de la entidad indicada. Para `:zonas` devuelve una
  tupla de trabajo (`{:z, zona}`, `{:s, cod_zona, sector}` o
  `{:p, cod_zona, cod_sector, punto}`); usar `de_lineas/2` para armar el árbol.
  """
  @spec de_linea(atom(), String.t()) :: {:ok, term()} | {:error, :linea_invalida}
  def de_linea(:usuarios, linea) do
    case dividir(linea) do
      [nombre, hash, completo, tipo, zona] ->
        {:ok,
         %Usuario{
           nombre_usuario: texto(nombre),
           hash_contrasena: texto(hash),
           nombre_completo: opcional(completo),
           tipo: atomo(tipo),
           zona: opcional(zona)
         }}

      _ ->
        {:error, :linea_invalida}
    end
  end

  def de_linea(:zonas, linea), do: zona_item(dividir(linea))

  def de_linea(:necesidades, linea) do
    with [id, tipo, descripcion, cant, cant_asig, zona, prioridad, reporta, creada, estado, asigs] <-
           dividir(linea),
         {:ok, cantidad} <- entero(cant),
         {:ok, cantidad_asignada} <- entero(cant_asig),
         {:ok, fecha} <- fecha(creada),
         {:ok, asignaciones} <- mapear_ok(lista(asigs), &asignacion/1) do
      {:ok,
       %Necesidad{
         id: texto(id),
         tipo: atomo(tipo),
         descripcion: opcional(descripcion),
         cantidad: cantidad,
         cantidad_asignada: cantidad_asignada,
         zona: texto(zona),
         prioridad: atomo(prioridad),
         reportado_por: opcional(reporta),
         creada_en: fecha,
         estado: atomo(estado),
         asignaciones: asignaciones
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(:recursos, linea) do
    with [codigo, nombre, categoria, unidad, zona, exist] <- dividir(linea),
         {:ok, pares} <- mapear_ok(lista(exist), &existencia/1) do
      {:ok,
       %Recurso{
         codigo: texto(codigo),
         nombre: texto(nombre),
         categoria: atomo(categoria),
         unidad: texto(unidad),
         zona: opcional(zona),
         existencias: Map.new(pares)
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(:movimientos, linea) do
    with [codigo, tipo, cant, ubicacion, referencia, usuario, fch] <- dividir(linea),
         {:ok, cantidad} <- entero(cant),
         {:ok, fecha} <- fecha(fch) do
      {:ok,
       %Movimiento{
         codigo_recurso: texto(codigo),
         tipo: atomo(tipo),
         cantidad: cantidad,
         ubicacion: texto(ubicacion),
         referencia: opcional(referencia),
         usuario: opcional(usuario),
         fecha: fecha
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(:personas, linea) do
    with [id, documento, nombre, edad, zona, estado, albergue, hist] <- dividir(linea),
         {:ok, edad_n} <- entero_opcional(edad),
         {:ok, historial} <- mapear_ok(lista(hist), &cambio_estado/1) do
      {:ok,
       %Persona{
         id: opcional(id),
         documento: texto(documento),
         nombre: texto(nombre),
         edad: edad_n,
         zona: texto(zona),
         estado: atomo(estado),
         albergue: opcional(albergue),
         historial: historial
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(:mensajes, linea) do
    with [id, destinatario, remitente, contenido, fch, estado] <- dividir(linea),
         {:ok, fecha} <- fecha(fch) do
      {:ok,
       %Mensaje{
         id: texto(id),
         destinatario: texto(destinatario),
         remitente: texto(remitente),
         contenido: texto(contenido),
         fecha: fecha,
         estado: atomo(estado)
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(:mascotas, linea) do
    case dividir(linea) do
      [id, tipo, especie, nombre, color, tamano, caract, zona, contacto, pareja, estado] ->
        {:ok,
         %Mascota{
           id: texto(id),
           tipo: atomo(tipo),
           especie: texto(especie),
           nombre: opcional(nombre),
           color: opcional(color),
           tamano: atomo_opcional(tamano),
           caracteristicas: caract |> lista() |> Enum.map(&desescapar/1) |> MapSet.new(),
           zona: texto(zona),
           contacto: opcional(contacto),
           pareja_id: opcional(pareja),
           estado: atomo(estado)
         }}

      _ ->
        {:error, :linea_invalida}
    end
  end

  def de_linea(:albergues, linea) do
    with [codigo, nombre, zona, cap, ocupantes] <- dividir(linea),
         {:ok, capacidad} <- entero(cap) do
      {:ok,
       %Albergue{
         codigo: texto(codigo),
         nombre: texto(nombre),
         zona: texto(zona),
         capacidad: capacidad,
         ocupantes: ocupantes |> lista() |> Enum.map(&desescapar/1) |> MapSet.new()
       }}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  def de_linea(_entidad, _linea), do: {:error, :linea_invalida}

  @doc """
  Decodifica todas las líneas de una entidad. Si una línea es inválida
  devuelve `{:error, {:linea_invalida, linea}}`. Para `:zonas` reconstruye el árbol.
  """
  @spec de_lineas(atom(), [String.t()]) :: {:ok, [struct()]} | {:error, term()}
  def de_lineas(entidad, lineas) do
    with {:ok, items} <- decodificar_todas(entidad, lineas, []) do
      case entidad do
        :zonas -> {:ok, armar_zonas(items)}
        _ -> {:ok, items}
      end
    end
  end

  ## ------------------------------------------------------------------
  ## Escape y división (RECURSIVAS sobre el texto)
  ## ------------------------------------------------------------------

  @doc "Escapa los caracteres especiales de un valor."
  @spec escapar(String.t()) :: String.t()
  def escapar(texto) do
    texto
    |> String.replace("\\", "\\\\")
    |> String.replace("|", "\\|")
    |> String.replace(";", "\\;")
    |> String.replace(":", "\\:")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end

  @doc "Inversa de `escapar/1` (RECURSIVA, carácter por carácter)."
  @spec desescapar(String.t()) :: String.t()
  def desescapar(texto), do: desescapar(texto, "")

  defp desescapar("", acum), do: acum
  defp desescapar(<<"\\", "n", resto::binary>>, acum), do: desescapar(resto, acum <> "\n")
  defp desescapar(<<"\\", "r", resto::binary>>, acum), do: desescapar(resto, acum <> "\r")

  defp desescapar(<<"\\", c::utf8, resto::binary>>, acum),
    do: desescapar(resto, acum <> <<c::utf8>>)

  defp desescapar(<<c::utf8, resto::binary>>, acum), do: desescapar(resto, acum <> <<c::utf8>>)
  defp desescapar(<<b, resto::binary>>, acum), do: desescapar(resto, acum <> <<b>>)

  @doc """
  Divide un texto por el separador indicado (por defecto `"|"`) ignorando los
  separadores escapados con `\\`. RECURSIVA sobre los caracteres. Los trozos
  devueltos siguen escapados (usar `desescapar/1` en cada hoja).

      iex> Emergencias.Persistencia.Codec.dividir("a|b\\\\|c|d")
      ["a", "b\\\\|c", "d"]
  """
  @spec dividir(String.t(), String.t()) :: [String.t()]
  def dividir(texto, separador \\ "|") when is_binary(texto) do
    dividir(texto, separador, "", [])
  end

  defp dividir("", _sep, actual, acum), do: Enum.reverse([actual | acum])

  defp dividir(<<"\\", c::utf8, resto::binary>>, sep, actual, acum),
    do: dividir(resto, sep, actual <> "\\" <> <<c::utf8>>, acum)

  defp dividir(<<c::utf8, resto::binary>>, sep, actual, acum) do
    caracter = <<c::utf8>>

    if caracter == sep do
      dividir(resto, sep, "", [actual | acum])
    else
      dividir(resto, sep, actual <> caracter, acum)
    end
  end

  defp dividir(<<b, resto::binary>>, sep, actual, acum), do: dividir(resto, sep, actual <> <<b>>, acum)

  ## ------------------------------------------------------------------
  ## Privadas: codificación de campos
  ## ------------------------------------------------------------------

  defp unir(campos), do: Enum.join(campos, "|")

  defp txt(nil), do: ""
  defp txt(texto) when is_binary(texto), do: escapar(texto)

  defp atm(nil), do: ""
  defp atm(atomo) when is_atom(atomo), do: atomo |> Atom.to_string() |> escapar()

  defp ent(nil), do: ""
  defp ent(entero) when is_integer(entero), do: Integer.to_string(entero)

  defp fch(nil), do: ""
  defp fch(%DateTime{} = fecha), do: fecha |> DateTime.to_iso8601() |> escapar()

  ## Privadas: decodificación de campos

  defp texto(campo), do: desescapar(campo)

  defp opcional(""), do: nil
  defp opcional(campo), do: desescapar(campo)

  defp atomo(campo), do: campo |> desescapar() |> String.to_atom()

  defp atomo_opcional(""), do: nil
  defp atomo_opcional(campo), do: atomo(campo)

  defp entero(campo) do
    case Integer.parse(campo) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp entero_opcional(""), do: {:ok, nil}
  defp entero_opcional(campo), do: entero(campo)

  defp fecha(""), do: {:ok, nil}

  defp fecha(campo) do
    case campo |> desescapar() |> DateTime.from_iso8601() do
      {:ok, fecha, _offset} -> {:ok, fecha}
      _ -> :error
    end
  end

  defp lista(""), do: []
  defp lista(campo), do: dividir(campo, ";")

  defp asignacion(item) do
    with [recurso, ubicacion, cant] <- dividir(item, ":"),
         {:ok, cantidad} <- entero(cant) do
      {:ok, {texto(recurso), texto(ubicacion), cantidad}}
    else
      _ -> :error
    end
  end

  defp existencia(item) do
    with [ubicacion, cant] <- dividir(item, ":"),
         {:ok, cantidad} <- entero(cant) do
      {:ok, {texto(ubicacion), cantidad}}
    else
      _ -> :error
    end
  end

  defp cambio_estado(item) do
    with [estado, fch, usuario] <- dividir(item, ":"),
         {:ok, fecha} <- fecha(fch) do
      {:ok, {atomo(estado), fecha, texto(usuario)}}
    else
      _ -> :error
    end
  end

  # RECURSIVA: aplica `fun` a cada elemento; se detiene en el primer :error.
  defp mapear_ok([], _fun), do: {:ok, []}

  defp mapear_ok([cabeza | cola], fun) do
    with {:ok, valor} <- fun.(cabeza),
         {:ok, resto} <- mapear_ok(cola, fun) do
      {:ok, [valor | resto]}
    end
  end

  # RECURSIVA con acumulador
  defp decodificar_todas(_entidad, [], acum), do: {:ok, Enum.reverse(acum)}

  defp decodificar_todas(entidad, [linea | resto], acum) do
    case de_linea(entidad, linea) do
      {:ok, registro} -> decodificar_todas(entidad, resto, [registro | acum])
      {:error, _} -> {:error, {:linea_invalida, linea}}
    end
  end

  ## Zonas

  defp zona_item(["Z", codigo, nombre, nivel, personas]) do
    with {:ok, p} <- entero(personas) do
      {:ok,
       {:z,
        %Zona{codigo: texto(codigo), nombre: texto(nombre), nivel: atomo(nivel), personas_estimadas: p}}}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  defp zona_item(["S", zona, codigo, nombre, nivel, personas]) do
    with {:ok, p} <- entero(personas) do
      {:ok,
       {:s, texto(zona),
        %Sector{codigo: texto(codigo), nombre: texto(nombre), nivel: atomo(nivel), personas_estimadas: p}}}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  defp zona_item(["P", zona, sector, codigo, nombre, personas]) do
    with {:ok, p} <- entero(personas) do
      {:ok,
       {:p, texto(zona), texto(sector),
        %PuntoAtencion{codigo: texto(codigo), nombre: texto(nombre), personas_estimadas: p}}}
    else
      _ -> {:error, :linea_invalida}
    end
  end

  defp zona_item(_otro), do: {:error, :linea_invalida}

  defp armar_zonas(items) do
    for {:z, zona} <- items do
      sectores =
        for {:s, cod_zona, sector} <- items, cod_zona == zona.codigo do
          puntos =
            for {:p, z, s, punto} <- items, z == zona.codigo, s == sector.codigo, do: punto

          %{sector | puntos: puntos}
        end

      %{zona | sectores: sectores}
    end
  end
end
