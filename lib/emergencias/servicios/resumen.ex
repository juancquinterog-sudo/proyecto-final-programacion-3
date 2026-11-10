defmodule Emergencias.Servicios.Resumen do
  @moduledoc """
  Consultas globales que combinan varios servidores (`zone_status`, y más
  adelante `summary`, `critical_resources`, reporte de albergues más ocupados).
  Combina los resultados con `Dominio.Estadisticas` y `Dominio.Zona`.
  """

  alias Emergencias.Dominio.Zona
  alias Emergencias.Servidores.{NecesidadServer, ZonaServer}

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

  @spec resumen_global() :: {:ok, map()}
  def resumen_global, do: {:ok, %{}}

  @spec recursos_criticos() :: [map()]
  def recursos_criticos, do: []

  @spec necesidades_pendientes() :: [map()]
  def necesidades_pendientes, do: NecesidadServer.pendientes()

  @spec albergues_mas_ocupados(pos_integer()) :: [map()]
  def albergues_mas_ocupados(_n \\ 5), do: []
end
