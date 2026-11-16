defmodule Emergencias.Cli.Comandos do
  @moduledoc """
  Despacha cada comando a su servidor/servicio. Pasos de CADA comando:

    1. Verificar sesión y permiso (`Dominio.Permisos.verificar/2`)
    2. Validar entradas (`Dominio.Validaciones`)
    3. Llamar al servidor o servicio
    4. Registrar en `Procesos.Bitacora` (nunca se registran contraseñas)
    5. Devolver `{:ok, sesion_nueva, mensaje}` | `{:error, razon}`

  Estado de implementación (se amplía en cada fase):

  | comando                  | destino                                   | fase |
  |--------------------------|-------------------------------------------|:----:|
  | connect / disconnect     | UsuarioServer                             |  4   |
  | help / exit              | (local)                                   |  4   |
  | register_zone, register_sector, register_point | ZonaServer          |  5a  |
  | list_zones, zone_status  | ZonaServer, Servicios.Resumen             |  5a  |
  | register_need, list_needs, pending_needs | NecesidadServer           |  5a  |
  | register_resource, list_resources, transfer_resource | RecursoServer |  5b  |
  | register_shelter, check_shelter, register_entry/exit | AlbergueServer |  5b  |
  | assign_resource          | Servicios.Asignador                       |  6   |
  | report_person, find_person, send/list_family_messages | PersonaServer |  7   |
  | report_pet, match_pets   | MascotaServer (+ Dominio.Similitud)       |  7   |
  | summary, critical_resources | Servicios.Resumen                      |  8   |
  """

  alias Emergencias.Cli.{Formato, Sesion}
  alias Emergencias.Dominio.{Albergue, Permisos, Recurso, Validaciones, Zona}
  alias Emergencias.Procesos.Bitacora
  alias Emergencias.Servicios.{Asignador, Resumen}

  alias Emergencias.Servidores.{
    AlbergueServer,
    MascotaServer,
    NecesidadServer,
    PersonaServer,
    RecursoServer,
    UsuarioServer,
    ZonaServer
  }

  @uso %{
    connect: "connect usuario contraseña [tipo zona]   (tipo y zona solo al registrarse)",
    disconnect: "disconnect",
    register_zone: "register_zone codigo nombre nivel [personas_estimadas]",
    register_sector: "register_sector zona codigo nombre [nivel] [personas_estimadas]",
    register_point: "register_point zona sector codigo nombre [personas_estimadas]",
    list_zones: "list_zones",
    zone_status: "zone_status zona",
    register_need: "register_need tipo cantidad prioridad zona descripcion",
    list_needs: "list_needs [zona=.. tipo=.. prioridad=.. estado=..]",
    assign_resource: "assign_resource necesidad categoria cantidad",
    register_resource: "register_resource codigo categoria cantidad unidad ubicacion",
    list_resources: "list_resources",
    transfer_resource: "transfer_resource codigo origen destino cantidad",
    report_person: "report_person documento nombre zona estado [edad=..]",
    find_person: "find_person documento",
    send_family_message: "send_family_message documento \"mensaje\"",
    list_family_messages: "list_family_messages documento",
    report_pet:
      "report_pet lost|found especie nombre color tamano zona contacto [caracteristicas=a,b]",
    match_pets: "match_pets",
    register_shelter: "register_shelter codigo \"nombre\" zona capacidad",
    check_shelter: "check_shelter codigo",
    register_entry: "register_entry codigo documento",
    register_exit: "register_exit codigo documento",
    summary: "summary",
    critical_resources: "critical_resources",
    pending_needs: "pending_needs",
    help: "help",
    exit: "exit"
  }

  @sin_sesion [:connect, :help, :exit]

  # Comandos implementados que exigen argumentos: si faltan, se muestra el uso.
  @con_argumentos [
    :register_zone,
    :register_sector,
    :register_point,
    :register_need,
    :zone_status,
    :register_resource,
    :transfer_resource,
    :assign_resource,
    :report_person,
    :find_person,
    :send_family_message,
    :list_family_messages,
    :report_pet,
    :register_shelter,
    :check_shelter,
    :register_entry,
    :register_exit
  ]

  @doc "Texto de uso de un comando."
  @spec uso(atom()) :: String.t()
  def uso(comando), do: Map.fetch!(@uso, comando)

  @spec ejecutar(Sesion.t(), {atom(), [String.t()], keyword()}) ::
          {:ok, Sesion.t(), String.t()} | {:error, term()}
  def ejecutar(%Sesion{} = sesion, {comando, argumentos, opciones}) do
    with :ok <- autorizar(sesion, comando) do
      sesion
      |> despachar(comando, argumentos, opciones)
      |> registrar_actividad(sesion, comando)
    end
  end

  ## Autorización

  defp autorizar(%Sesion{usuario: nil}, comando) when comando in @sin_sesion, do: :ok
  defp autorizar(%Sesion{usuario: nil}, _comando), do: {:error, :no_conectado}
  defp autorizar(%Sesion{tipo: tipo}, comando), do: Permisos.verificar(tipo, comando)

  ## Sesión

  defp despachar(%Sesion{usuario: nil}, :connect, [usuario, contrasena | resto], _opciones) do
    tipo = Enum.at(resto, 0)
    zona = Enum.at(resto, 1)

    case UsuarioServer.conectar(usuario, contrasena, tipo, zona) do
      {:ok, u, :registrado} ->
        {:ok, sesion_de(u),
         "Usuario '#{u.nombre_usuario}' registrado como #{u.tipo} en la zona '#{u.zona}'. Sesión iniciada."}

      {:ok, u, :autenticado} ->
        {:ok, sesion_de(u),
         "Bienvenido de nuevo, #{u.nombre_usuario} (#{u.tipo}, zona #{u.zona})."}

      {:error, _razon} = error ->
        error
    end
  end

  defp despachar(%Sesion{usuario: nil}, :connect, _argumentos, _opciones),
    do: {:error, {:uso, uso(:connect)}}

  defp despachar(%Sesion{}, :connect, _argumentos, _opciones), do: {:error, :ya_conectado}

  defp despachar(%Sesion{usuario: usuario}, :disconnect, _argumentos, _opciones) do
    _ = UsuarioServer.desconectar(usuario)
    {:ok, Sesion.anonima(), "Sesión de '#{usuario}' cerrada."}
  end

  defp despachar(%Sesion{usuario: usuario}, :exit, _argumentos, _opciones) do
    if usuario, do: UsuarioServer.desconectar(usuario)
    {:ok, Sesion.anonima(), "Hasta luego."}
  end

  defp despachar(%Sesion{tipo: tipo} = sesion, :help, _argumentos, _opciones) do
    comandos =
      case tipo do
        nil -> @sin_sesion
        tipo -> Permisos.comandos_permitidos(tipo)
      end

    lineas = Enum.map(comandos, fn comando -> "  " <> uso(comando) end)
    {:ok, sesion, Enum.join(["Comandos disponibles:" | lineas], "\n")}
  end

  ## Zonas

  defp despachar(sesion, :register_zone, [codigo, nombre, nivel | resto], _opciones) do
    datos = %{codigo: codigo, nombre: nombre, nivel: nivel, personas_estimadas: Enum.at(resto, 0)}

    datos
    |> ZonaServer.registrar()
    |> responder(sesion, fn z ->
      "Zona '#{z.codigo}' registrada (#{z.nombre}, nivel #{z.nivel}, #{z.personas_estimadas} personas)."
    end)
  end

  defp despachar(sesion, :register_sector, [zona, codigo, nombre | resto], _opciones) do
    datos = %{
      codigo: codigo,
      nombre: nombre,
      nivel: Enum.at(resto, 0),
      personas_estimadas: Enum.at(resto, 1)
    }

    zona
    |> ZonaServer.agregar_sector(datos)
    |> responder(sesion, fn _ -> "Sector '#{codigo}' agregado a la zona '#{zona}'." end)
  end

  defp despachar(sesion, :register_point, [zona, sector, codigo, nombre | resto], _opciones) do
    datos = %{codigo: codigo, nombre: nombre, personas_estimadas: Enum.at(resto, 0)}

    zona
    |> ZonaServer.agregar_punto(sector, datos)
    |> responder(sesion, fn _ ->
      "Punto de atención '#{codigo}' agregado al sector '#{sector}' de la zona '#{zona}'."
    end)
  end

  defp despachar(sesion, :list_zones, _argumentos, _opciones) do
    filas =
      Enum.map(ZonaServer.listar(), fn z ->
        [
          z.codigo,
          z.nombre,
          z.nivel,
          Zona.total_afectados(z),
          length(z.sectores),
          Zona.contar_puntos(z)
        ]
      end)

    {:ok, sesion,
     Formato.tabla(["codigo", "nombre", "nivel", "afectados", "sectores", "puntos"], filas)}
  end

  defp despachar(sesion, :zone_status, [codigo | _], _opciones) do
    codigo
    |> Resumen.estado_zona()
    |> responder(sesion, &Formato.estado_zona/1)
  end

  ## Necesidades

  defp despachar(
         %Sesion{usuario: usuario} = sesion,
         :register_need,
         [tipo, cantidad, prioridad, zona | descripcion],
         _opciones
       ) do
    datos = %{
      tipo: tipo,
      cantidad: cantidad,
      prioridad: prioridad,
      zona: zona,
      descripcion: Enum.join(descripcion, " "),
      reportado_por: usuario
    }

    datos
    |> NecesidadServer.registrar()
    |> responder(sesion, fn n ->
      "Necesidad #{n.id} registrada: #{n.cantidad} de #{n.tipo} (prioridad #{n.prioridad}) en la zona '#{n.zona}'."
    end)
  end

  defp despachar(sesion, :list_needs, _argumentos, opciones) do
    with {:ok, filtros} <- filtros_necesidad(opciones) do
      {:ok, sesion, filtros |> NecesidadServer.listar() |> Formato.necesidades()}
    end
  end

  defp despachar(sesion, :pending_needs, _argumentos, _opciones),
    do: {:ok, sesion, Formato.necesidades(NecesidadServer.pendientes())}

  ## Recursos y asignación

  defp despachar(
         %Sesion{usuario: u} = sesion,
         :register_resource,
         [codigo, categoria, cantidad, unidad, ubicacion | _],
         _o
       ) do
    datos = %{
      codigo: codigo,
      nombre: codigo,
      categoria: categoria,
      cantidad: cantidad,
      unidad: unidad,
      ubicacion: ubicacion,
      usuario: u,
      fecha: ahora()
    }

    with {:ok, recurso} <- Recurso.nuevo(datos),
         {:ok, _pid} <- RecursoServer.registrar(recurso) do
      {:ok, sesion,
       "Recurso '#{codigo}' registrado: #{Recurso.total(recurso)} #{unidad} de #{recurso.categoria} en '#{ubicacion}'."}
    end
  end

  defp despachar(sesion, :list_resources, _argumentos, _opciones),
    do: {:ok, sesion, Formato.recursos(RecursoServer.listar())}

  defp despachar(
         %Sesion{usuario: u} = sesion,
         :transfer_resource,
         [codigo, origen, destino, cantidad | _],
         _o
       ) do
    codigo
    |> RecursoServer.transferir(origen, destino, cantidad_o_error(cantidad), %{usuario: u})
    |> responder(sesion, fn _ ->
      "Transferidas #{cantidad} unidades de '#{codigo}': #{origen} -> #{destino}."
    end)
  end

  defp despachar(
         %Sesion{usuario: u} = sesion,
         :assign_resource,
         [necesidad, categoria, cantidad | _],
         _o
       ) do
    necesidad
    |> String.upcase()
    |> Asignador.asignar(categoria, cantidad, u)
    |> responder(sesion, fn %{necesidad: id, tomado: tomado} ->
      detalle = Enum.map_join(tomado, ", ", fn {r, ub, c} -> "#{c} de #{r} (#{ub})" end)
      "Necesidad #{id}: asignados #{detalle}."
    end)
  end

  ## Albergues

  defp despachar(sesion, :register_shelter, [codigo, nombre, zona, capacidad | _], _o) do
    with {:ok, albergue} <-
           Albergue.nuevo(%{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad}),
         {:ok, _pid} <- AlbergueServer.registrar(albergue) do
      {:ok, sesion,
       "Albergue '#{codigo}' (#{nombre}) registrado con capacidad #{albergue.capacidad}."}
    end
  end

  defp despachar(sesion, :check_shelter, [codigo | _], _o) do
    codigo |> AlbergueServer.consultar() |> responder(sesion, fn a -> Formato.albergues([a]) end)
  end

  defp despachar(sesion, :register_entry, [codigo, documento | _], _o) do
    codigo
    |> AlbergueServer.registrar_entrada(documento)
    |> responder(sesion, fn a ->
      "Ingreso registrado en '#{codigo}'. Cupos disponibles: #{Albergue.cupos(a)}."
    end)
  end

  defp despachar(sesion, :register_exit, [codigo, documento | _], _o) do
    codigo
    |> AlbergueServer.registrar_salida(documento)
    |> responder(sesion, fn a ->
      "Salida registrada en '#{codigo}'. Cupos disponibles: #{Albergue.cupos(a)}."
    end)
  end

  ## Personas y mensajes

  defp despachar(
         %Sesion{usuario: u} = sesion,
         :report_person,
         [documento, nombre, zona | resto],
         opciones
       ) do
    datos = %{
      documento: documento,
      nombre: nombre,
      zona: zona,
      estado: Enum.at(resto, 0),
      edad: opciones[:edad],
      usuario: u
    }

    datos
    |> PersonaServer.reportar()
    |> responder(sesion, fn p ->
      "Persona #{p.nombre} (#{p.documento}) registrada con estado #{p.estado} en '#{p.zona}'."
    end)
  end

  defp despachar(sesion, :find_person, [documento | _], _o) do
    {:ok, sesion, Formato.personas(PersonaServer.buscar(documento: documento))}
  end

  defp despachar(
         %Sesion{usuario: u} = sesion,
         :send_family_message,
         [documento, contenido | _],
         _o
       ) do
    %{destinatario: documento, remitente: u, contenido: contenido}
    |> PersonaServer.enviar_mensaje()
    |> responder(sesion, fn m -> "Mensaje #{m.id} guardado para #{documento} (#{m.estado})." end)
  end

  defp despachar(sesion, :list_family_messages, [documento | _], _o),
    do: {:ok, sesion, Formato.mensajes(PersonaServer.listar_mensajes(documento))}

  ## Mascotas

  defp despachar(
         sesion,
         :report_pet,
         [tipo, especie, nombre, color, tamano, zona, contacto | _],
         opciones
       ) do
    datos = %{
      tipo: tipo,
      especie: especie,
      nombre: nombre,
      color: color,
      tamano: tamano,
      zona: zona,
      contacto: contacto,
      caracteristicas: opciones[:caracteristicas]
    }

    datos
    |> MascotaServer.reportar()
    |> responder(sesion, fn m ->
      "Reporte #{m.id} registrado (#{m.tipo} #{m.especie}) en '#{m.zona}'."
    end)
  end

  defp despachar(sesion, :match_pets, _argumentos, _opciones),
    do: {:ok, sesion, Formato.coincidencias(MascotaServer.buscar_coincidencias())}

  ## Resumen

  defp despachar(sesion, :summary, _argumentos, _opciones) do
    {:ok, resumen} = Resumen.resumen_global()
    {:ok, sesion, Formato.resumen(resumen)}
  end

  defp despachar(sesion, :critical_resources, _argumentos, _opciones) do
    texto =
      "Recursos con existencias <= #{Resumen.umbral_critico()}:\n" <>
        Formato.recursos(Resumen.recursos_criticos())

    {:ok, sesion, texto}
  end

  ## Uso incorrecto y comandos de fases posteriores

  defp despachar(_sesion, comando, _argumentos, _opciones) when comando in @con_argumentos,
    do: {:error, {:uso, uso(comando)}}

  defp despachar(_sesion, _comando, _argumentos, _opciones), do: {:error, :no_implementado}

  ## Auxiliares

  defp ahora, do: DateTime.utc_now() |> DateTime.truncate(:second)

  # Convierte "30" -> 30; si no es entero válido deja el texto (el dominio lo rechaza).
  defp cantidad_o_error(cantidad) do
    case Validaciones.entero_positivo(cantidad) do
      {:ok, n} -> n
      {:error, _} -> cantidad
    end
  end

  defp responder({:ok, valor}, sesion, fun), do: {:ok, sesion, fun.(valor)}
  defp responder({:error, _razon} = error, _sesion, _fun), do: error

  # Convierte los filtros de texto de la consola en valores normalizados.
  defp filtros_necesidad(opciones) do
    Enum.reduce_while(opciones, {:ok, []}, fn {clave, valor}, {:ok, acum} ->
      case filtro(clave, valor) do
        {:ok, par} -> {:cont, {:ok, acum ++ [par]}}
        :ignorar -> {:cont, {:ok, acum}}
        {:error, _razon} = error -> {:halt, error}
      end
    end)
  end

  defp filtro(:zona, valor), do: {:ok, {:zona, valor}}

  defp filtro(:tipo, valor),
    do: with({:ok, t} <- Validaciones.tipo_necesidad(valor), do: {:ok, {:tipo, t}})

  defp filtro(:prioridad, valor),
    do: with({:ok, p} <- Validaciones.prioridad(valor), do: {:ok, {:prioridad, p}})

  defp filtro(:estado, valor),
    do: with({:ok, e} <- Validaciones.estado(:necesidad, valor), do: {:ok, {:estado, e}})

  defp filtro(_otra, _valor), do: :ignorar

  ## Bitácora (sin datos sensibles)

  defp registrar_actividad({:ok, nueva, _mensaje} = resultado, sesion, comando) do
    Bitacora.registrar(nueva.usuario || sesion.usuario || "anonimo", comando, :ok)
    resultado
  end

  defp registrar_actividad({:error, razon} = resultado, sesion, comando) do
    Bitacora.registrar(sesion.usuario || "anonimo", comando, {:error, razon})
    resultado
  end

  defp sesion_de(usuario) do
    %Sesion{usuario: usuario.nombre_usuario, tipo: usuario.tipo, zona: usuario.zona}
  end
end
