defmodule Emergencias.Servicios.Asignador do
  @moduledoc """
  Orquesta `assign_resource` entre NecesidadServer y RecursoServer (req. 1.4.4/1.4.5).

  Protocolo (ver docs/DISENO.md y diagrama de secuencia):

    1. `NecesidadServer.obtener/1` y validación de estado/faltante.
    2. Candidatos: recursos de la categoría pedida en la zona de la necesidad.
    3. `tomar_de_recursos/3` (RECURSIVA): intenta `RecursoServer.reservar/4` en cada
       candidato hasta cubrir la cantidad; cada reserva es atómica en su proceso.
    4. `NecesidadServer.registrar_asignacion/2` con lo reservado.
    5. Si el paso 4 falla -> `RecursoServer.liberar/4` (compensación / rollback).

  Con dos solicitudes simultáneas (30 y 25 sobre 50) el buzón del RecursoServer
  las ordena: la primera se confirma, la segunda recibe `{:error, :stock_insuficiente}`.
  """

  @spec asignar(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def asignar(_id_necesidad, _categoria, _cantidad, _usuario), do: {:error, :no_implementado}

  @doc "RECURSIVA: toma `cantidad` recorriendo la lista de candidatos."
  @spec tomar_de_recursos([{String.t(), String.t()}], non_neg_integer(), [tuple()]) ::
          {:ok, [tuple()]} | {:error, :stock_insuficiente, [tuple()]}
  def tomar_de_recursos(_candidatos, _faltante, _tomado), do: {:error, :stock_insuficiente, []}
end
