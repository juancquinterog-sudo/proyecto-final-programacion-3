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
  | register_zone            | ZonaServer                                |  5   |
  | register_need, list_needs| NecesidadServer                           |  5   |
  | assign_resource          | Servicios.Asignador                       |  6   |
  | register_resource, list_resources, transfer_resource | RecursoServer |  5   |
  | report_person, find_person, send/list_family_messages | PersonaServer |  7   |
  | report_pet, match_pets   | MascotaServer (+ Dominio.Similitud)       |  7   |
  | register_shelter, check_shelter, register_entry/exit | AlbergueServer |  5   |
  | summary, critical_resources, pending_needs | Servicios.Resumen       |  8   |
  """

  alias Emergencias.Cli.Sesion
  alias Emergencias.Dominio.Permisos
  alias Emergencias.Procesos.Bitacora
  alias Emergencias.Servidores.UsuarioServer

  @uso %{
    connect: "connect usuario contraseña [tipo zona]   (tipo y zona solo al registrarse)",
    disconnect: "disconnect",
    register_zone: "register_zone codigo nombre nivel",
    register_need: "register_need tipo cantidad prioridad zona descripcion",
    list_needs: "list_needs [zona=.. tipo=.. prioridad=.. estado=..]",
    assign_resource: "assign_resource necesidad recurso cantidad",
    register_resource: "register_resource codigo categoria cantidad unidad ubicacion",
    list_resources: "list_resources",
    transfer_resource: "transfer_resource codigo origen destino cantidad",
    report_person: "report_person documento nombre zona estado [edad=..]",
    find_person: "find_person documento",
    send_family_message: "send_family_message documento \"mensaje\"",
    list_family_messages: "list_family_messages documento",
    report_pet: "report_pet lost|found especie nombre color tamano zona contacto",
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

  ## Despacho

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

  # Comandos de las fases siguientes.
  defp despachar(_sesion, _comando, _argumentos, _opciones), do: {:error, :no_implementado}

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
