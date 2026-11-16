defmodule Emergencias.Servicios.Resumen do
  @moduledoc """
  Consultas globales que combinan varios servidores (`zone_status`, y más
  adelante `summary`, `critical_resources`, reporte de albergues más ocupados).
  Combina los resultados con `Dominio.Estadisticas` y `Dominio.Zona`.
  """

  alias Emergencias.Dominio.{Estadisticas, Recurso, Zona}

  alias Emergencias.Servidores.{
    AlbergueServer,
    MascotaServer,
    NecesidadServer,
    PersonaServer,
    RecursoServer,
    ZonaServer
  }

  # Un recurso es "crítico" cuando su inventario total es menor o igual a este valor.
  @umbral_critico 20

  @doc "Estado general de una zona: la zona, sus estadísticas y sus necesidades."
  @spec estado_zona(String.t()) :: {:ok, map()} | {:error, :no_existe}
  def estado_zona(codigo) do
    with {:ok, zona} <- ZonaServer.consultar(codigo) do
      {:ok,
       %{
         zona: zona,
         estadisticas: Zona.estadisticas(zona),
         necesidades: NecesidadServer.listar(zona: codigo)
       }}
    end
  end

  @doc "Resumen global para el coordinador (`summary`)."
  @spec resumen_global() :: {:ok, map()}
  def resumen_global do
    necesidades = NecesidadServer.listar()
    recursos = RecursoServer.listar()
    %{personas: personas, mensajes: mensajes} = PersonaServer.todo()
    mascotas = MascotaServer.listar()

    {:ok,
     %{
       zonas: length(ZonaServer.listar()),
       necesidades: %{
         total: length(necesidades),
         pendientes: necesidades |> Estadisticas.necesidades_pendientes() |> length(),
         por_estado: conteos(necesidades, & &1.estado)
       },
       recursos:
         Enum.map(recursos, fn r ->
           %{codigo: r.codigo, nombre: r.nombre, total: Recurso.total(r), unidad: r.unidad}
         end),
       recursos_criticos: recursos |> Estadisticas.recursos_criticos(@umbral_critico) |> length(),
       personas: %{total: length(personas), por_estado: conteos(personas, & &1.estado)},
       mensajes: %{
         total: length(mensajes),
         pendientes: Estadisticas.contar_si(mensajes, &(&1.estado == :pendiente))
       },
       mascotas: %{total: length(mascotas), por_estado: conteos(mascotas, & &1.estado)},
       albergues_mas_ocupados: albergues_mas_ocupados(3)
     }}
  end

  @spec recursos_criticos(non_neg_integer()) :: [Recurso.t()]
  def recursos_criticos(umbral \\ @umbral_critico),
    do: Estadisticas.recursos_criticos(RecursoServer.listar(), umbral)

  def umbral_critico, do: @umbral_critico

  @spec necesidades_pendientes() :: [map()]
  def necesidades_pendientes, do: NecesidadServer.pendientes()

  @spec albergues_mas_ocupados(pos_integer()) :: [map()]
  def albergues_mas_ocupados(n \\ 5),
    do: Estadisticas.albergues_mas_ocupados(AlbergueServer.listar(), n)

  defp conteos(lista, fun_clave),
    do: lista |> Estadisticas.agrupar(fun_clave) |> Map.new(fn {k, v} -> {k, length(v)} end)
end
