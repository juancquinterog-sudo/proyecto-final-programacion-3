defmodule Emergencias.Cli.Comandos do
  @moduledoc """
  Despacha cada comando a su servidor/servicio. Pasos de CADA comando:

    1. Verificar sesión y permiso (`Dominio.Permisos.verificar/2`)
    2. Validar entradas (`Dominio.Validaciones`)
    3. Llamar al servidor o servicio
    4. Registrar en `Procesos.Bitacora`
    5. Devolver `{:ok, sesion_nueva, mensaje}` | `{:error, razon}`

  Tabla comando -> destino:

  | comando                  | destino                                   |
  |--------------------------|-------------------------------------------|
  | connect / disconnect     | UsuarioServer                             |
  | register_zone            | ZonaServer                                |
  | register_need, list_needs| NecesidadServer                           |
  | assign_resource          | Servicios.Asignador                       |
  | register_resource        | RecursoServer.registrar / entrada         |
  | list_resources           | RecursoServer.listar                      |
  | transfer_resource        | RecursoServer.transferir                  |
  | report_person, find_person| PersonaServer                            |
  | send/list_family_messages| PersonaServer                             |
  | report_pet, match_pets   | MascotaServer (+ Dominio.Similitud)       |
  | register_shelter, check_shelter, register_entry/exit | AlbergueServer|
  | summary, critical_resources, pending_needs | Servicios.Resumen       |
  """

  alias Emergencias.Cli.Sesion

  @spec ejecutar(Sesion.t(), {atom(), [String.t()], keyword()}) ::
          {:ok, Sesion.t(), String.t()} | {:error, atom()}
  def ejecutar(_sesion, _comando), do: {:error, :no_implementado}
end
