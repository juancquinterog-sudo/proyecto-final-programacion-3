defmodule Emergencias.Servicios.Asignador do
  @moduledoc """
  Orquesta la asignación de recursos para satisfacer necesidades (req. 1.4.4 / 1.4.5).

  Garantía de concurrencia (dos capas):

    1. Cada `RecursoServer` descuenta de forma atómica (un proceso por recurso):
       nunca entrega más de lo que hay.
    2. Las asignaciones de una misma categoría se serializan con un lock global
       (`:global.trans`), de modo que dos solicitudes simultáneas no se
       "estorben" reservando parcialmente el mismo inventario.

  La asignación es TODO-O-NADA: si el inventario total de la categoría no
  alcanza, o si la necesidad rechaza el registro, todo lo reservado se
  devuelve (compensación / rollback) y el resultado es `{:error, razon}`.
  """

  alias Emergencias.Dominio.{Necesidad, Recurso, Validaciones}
  alias Emergencias.Servidores.{NecesidadServer, RecursoServer}

  @spec asignar(String.t(), String.t(), pos_integer() | String.t(), String.t()) ::
          {:ok, %{necesidad: String.t(), tomado: [{String.t(), String.t(), pos_integer()}]}}
          | {:error, atom()}
  def asignar(id_necesidad, categoria, cantidad, _usuario) do
    with {:ok, cantidad} <- Validaciones.entero_positivo(cantidad),
         {:ok, necesidad} <- NecesidadServer.obtener(id_necesidad),
         :ok <- validar_necesidad(necesidad, categoria, cantidad) do
      :global.trans({{:asignar, to_string(categoria)}, self()}, fn ->
        reservar_y_registrar(necesidad, categoria, cantidad)
      end)
    end
  end

  defp validar_necesidad(necesidad, categoria, cantidad) do
    cond do
      necesidad.estado in [:atendida, :cancelada] -> {:error, :necesidad_cerrada}
      to_string(necesidad.tipo) != to_string(categoria) -> {:error, :categoria_distinta}
      cantidad > Necesidad.faltante(necesidad) -> {:error, :excede_requerido}
      true -> :ok
    end
  end

  defp reservar_y_registrar(necesidad, categoria, cantidad) do
    candidatos = candidatos(categoria)

    case reservar(candidatos, cantidad, necesidad.id, []) do
      {:ok, tomado} ->
        case NecesidadServer.registrar_asignaciones(necesidad.id, tomado) do
          {:ok, _} ->
            {:ok, %{necesidad: necesidad.id, tomado: tomado}}

          {:error, razon} ->
            devolver(tomado, necesidad.id)
            {:error, razon}
        end

      {:error, razon, parcial} ->
        devolver(parcial, necesidad.id)
        {:error, razon}
    end
  end

  # Pares {codigo, ubicacion} de la categoría, de más a menos stock.
  defp candidatos(categoria) do
    RecursoServer.listar()
    |> Enum.filter(fn r -> to_string(r.categoria) == to_string(categoria) end)
    |> Enum.flat_map(fn r ->
      Enum.map(Recurso.con_stock(r), fn {ub, cant} -> {r.codigo, ub, cant} end)
    end)
    |> Enum.sort_by(fn {codigo, ub, cant} -> {-cant, codigo, ub} end)
  end

  # RECURSIVA: toma de cada ubicación lo que haga falta hasta cubrir `faltante`.
  defp reservar(_candidatos, 0, _id, tomado), do: {:ok, Enum.reverse(tomado)}
  defp reservar([], _faltante, _id, tomado), do: {:error, :stock_insuficiente, tomado}

  defp reservar([{codigo, ubicacion, visto} | resto], faltante, id, tomado) do
    pedir = min(faltante, visto)

    case RecursoServer.reservar(codigo, ubicacion, pedir, id) do
      {:ok, _} -> reservar(resto, faltante - pedir, id, [{codigo, ubicacion, pedir} | tomado])
      {:error, _} -> reservar(resto, faltante, id, tomado)
    end
  end

  defp devolver(tomado, id) do
    Enum.each(tomado, fn {codigo, ubicacion, cantidad} ->
      RecursoServer.liberar(codigo, ubicacion, cantidad, id)
    end)
  end
end
