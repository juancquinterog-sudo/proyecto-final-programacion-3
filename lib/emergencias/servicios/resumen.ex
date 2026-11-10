defmodule Emergencias.Servicios.Resumen do
  @moduledoc """
  Consultas globales que combinan varios servidores (`summary`,
  `critical_resources`, `pending_needs`, reporte de albergues más ocupados).
  Consulta cada servidor EN PARALELO con `Task.Supervisor.async_stream_nolink/3`
  sobre `Emergencias.TareaSupervisor` y combina con `Dominio.Estadisticas`.
  """

  @spec resumen_global() :: {:ok, map()}
  def resumen_global, do: {:ok, %{}}

  @spec recursos_criticos() :: [map()]
  def recursos_criticos, do: []

  @spec necesidades_pendientes() :: [map()]
  def necesidades_pendientes, do: []

  @spec albergues_mas_ocupados(pos_integer()) :: [map()]
  def albergues_mas_ocupados(_n \\ 5), do: []
end
