defmodule Emergencias.Dominio.Permisos do
  @moduledoc """
  Restricción de operaciones según el tipo de usuario (req. 1.4.1).

  Los roles forman una jerarquía (ciudadano < voluntario < coordinador <
  administrador). Cada comando tiene un ROL MÍNIMO; quien tenga ese rol o uno
  superior puede ejecutarlo. Un comando desconocido no está permitido.

  | rol mínimo    | comandos                                                                  |
  |---------------|---------------------------------------------------------------------------|
  | ciudadano     | connect, disconnect, help, exit, register_need, list_needs, pending_needs,|
  |               | report_person, find_person, send_family_message, list_family_messages,    |
  |               | report_pet, match_pets, check_shelter, list_zones, zone_status             |
  | voluntario    | list_resources, register_entry, register_exit                              |
  | coordinador   | register_zone, register_sector, register_point, register_resource, assign_resource, transfer_resource,      |
  |               | register_shelter, summary, critical_resources                              |
  | administrador | (todo lo anterior)                                                         |
  """

  alias Emergencias.Dominio.Usuario

  @rango %{ciudadano: 0, voluntario: 1, coordinador: 2, administrador: 3}

  @minimo %{
    connect: :ciudadano,
    disconnect: :ciudadano,
    help: :ciudadano,
    exit: :ciudadano,
    register_need: :ciudadano,
    list_needs: :ciudadano,
    pending_needs: :ciudadano,
    report_person: :ciudadano,
    find_person: :ciudadano,
    send_family_message: :ciudadano,
    list_family_messages: :ciudadano,
    report_pet: :ciudadano,
    match_pets: :ciudadano,
    check_shelter: :ciudadano,
    list_resources: :voluntario,
    register_entry: :voluntario,
    register_exit: :voluntario,
    list_zones: :ciudadano,
    zone_status: :ciudadano,
    register_zone: :coordinador,
    register_sector: :coordinador,
    register_point: :coordinador,
    register_resource: :coordinador,
    assign_resource: :coordinador,
    transfer_resource: :coordinador,
    register_shelter: :coordinador,
    summary: :coordinador,
    critical_resources: :coordinador
  }

  @doc "Indica si un tipo de usuario puede ejecutar un comando."
  @spec permitido?(Usuario.tipo(), atom()) :: boolean()
  def permitido?(tipo, comando) do
    with {:ok, rango_usuario} <- Map.fetch(@rango, tipo),
         {:ok, minimo} <- Map.fetch(@minimo, comando) do
      rango_usuario >= Map.fetch!(@rango, minimo)
    else
      :error -> false
    end
  end

  @doc "Versión con tupla de resultado: `:ok | {:error, :sin_permiso}`."
  @spec verificar(Usuario.tipo(), atom()) :: :ok | {:error, :sin_permiso}
  def verificar(tipo, comando) do
    if permitido?(tipo, comando), do: :ok, else: {:error, :sin_permiso}
  end

  @doc "Comandos que puede ejecutar un tipo de usuario (para el comando `help`)."
  @spec comandos_permitidos(Usuario.tipo()) :: [atom()]
  def comandos_permitidos(tipo) do
    @minimo
    |> Map.keys()
    |> Enum.filter(fn comando -> permitido?(tipo, comando) end)
    |> Enum.sort()
  end
end
