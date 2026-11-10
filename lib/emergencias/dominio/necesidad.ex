defmodule Emergencias.Dominio.Necesidad do
  @moduledoc """
  Necesidad puntual de ayuda (req. 1.4.4). Módulo puro.

  Tipos: `:agua | :alimentos | :medicamentos | :primeros_auxilios | :refugio |
  :transporte | :rescate | :otra`.

  Prioridad (`:critica > :alta > :media > :baja`) NO es informativa: se usa en
  `insertar_por_prioridad/2` y `ordenar/1` para decidir a quién atender primero.
  A igual prioridad se respeta el orden de llegada (orden estable).

  Una necesidad `:atendida` o `:cancelada` está cerrada: no admite más
  asignaciones ni cambios de estado.
  """

  alias Emergencias.Dominio.{Estados, Validaciones}

  @prioridades [:critica, :alta, :media, :baja]

  @enforce_keys [:id, :tipo, :cantidad, :zona, :prioridad]
  defstruct [
    :id,
    :tipo,
    :descripcion,
    :cantidad,
    :zona,
    :prioridad,
    :reportado_por,
    :creada_en,
    cantidad_asignada: 0,
    estado: :pendiente,
    asignaciones: []
  ]

  @type t :: %__MODULE__{}

  def prioridades, do: @prioridades

  @doc "Peso numérico de una prioridad (menor = más urgente)."
  def peso(:critica), do: 0
  def peso(:alta), do: 1
  def peso(:media), do: 2
  def peso(:baja), do: 3

  @doc """
  Crea una necesidad `:pendiente`. `datos`: `:id`, `:tipo`, `:cantidad`, `:zona`,
  `:prioridad` (obligatorios) y `:descripcion`, `:reportado_por`, `:creada_en`
  (opcionales; la fecha la aporta quien llama para mantener el módulo puro).
  """
  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(datos) when is_map(datos) do
    with {:ok, id} <- Validaciones.texto_no_vacio(Map.get(datos, :id)),
         {:ok, tipo} <- Validaciones.tipo_necesidad(Map.get(datos, :tipo)),
         {:ok, cantidad} <- Validaciones.entero_positivo(Map.get(datos, :cantidad)),
         {:ok, zona} <- Validaciones.texto_no_vacio(Map.get(datos, :zona)),
         {:ok, prioridad} <- Validaciones.prioridad(Map.get(datos, :prioridad)) do
      {:ok,
       %__MODULE__{
         id: id,
         tipo: tipo,
         descripcion: Map.get(datos, :descripcion) || "",
         cantidad: cantidad,
         zona: zona,
         prioridad: prioridad,
         reportado_por: Map.get(datos, :reportado_por),
         creada_en: Map.get(datos, :creada_en)
       }}
    end
  end

  @doc "Cambia el estado validando la transición (`Estados.transicion/3`)."
  @spec cambiar_estado(t(), atom()) :: {:ok, t()} | {:error, :necesidad_cerrada | :transicion_invalida}
  def cambiar_estado(%__MODULE__{estado: actual} = necesidad, nuevo) do
    if Estados.terminal?(:necesidad, actual) do
      {:error, :necesidad_cerrada}
    else
      with {:ok, estado} <- Estados.transicion(:necesidad, actual, nuevo) do
        {:ok, %{necesidad | estado: estado}}
      end
    end
  end

  @doc """
  Registra una asignación `{codigo_recurso, ubicacion, cantidad}`. Rechaza
  necesidades cerradas y cantidades que excedan lo que falta. La primera
  asignación pasa la necesidad de `:pendiente` a `:asignada`.
  """
  @spec registrar_asignacion(t(), {String.t(), String.t(), pos_integer()}) ::
          {:ok, t()} | {:error, atom()}
  def registrar_asignacion(%__MODULE__{} = necesidad, {codigo, ubicacion, cantidad})
      when is_binary(codigo) and is_binary(ubicacion) and is_integer(cantidad) and cantidad > 0 do
    cond do
      Estados.terminal?(:necesidad, necesidad.estado) ->
        {:error, :necesidad_cerrada}

      cantidad > faltante(necesidad) ->
        {:error, :excede_requerido}

      true ->
        actualizada = %{
          necesidad
          | cantidad_asignada: necesidad.cantidad_asignada + cantidad,
            asignaciones: necesidad.asignaciones ++ [{codigo, ubicacion, cantidad}]
        }

        if actualizada.estado == :pendiente,
          do: cambiar_estado(actualizada, :asignada),
          else: {:ok, actualizada}
    end
  end

  def registrar_asignacion(%__MODULE__{}, _otra), do: {:error, :asignacion_invalida}

  @doc "Cantidad que aún falta cubrir."
  @spec faltante(t()) :: non_neg_integer()
  def faltante(%__MODULE__{cantidad: c, cantidad_asignada: a}), do: max(c - a, 0)

  @doc "¿La necesidad ya tiene toda su cantidad cubierta?"
  @spec cubierta?(t()) :: boolean()
  def cubierta?(%__MODULE__{} = necesidad), do: faltante(necesidad) == 0

  ## ---------------- RECURSIVAS ----------------

  @doc """
  Inserta en una lista ya ordenada por prioridad (recursivo). Va detrás de las
  de igual prioridad, así se respeta el orden de llegada.
  """
  @spec insertar_por_prioridad([t()], t()) :: [t()]
  def insertar_por_prioridad([], %__MODULE__{} = necesidad), do: [necesidad]

  def insertar_por_prioridad([cabeza | cola] = lista, %__MODULE__{} = necesidad) do
    if peso(necesidad.prioridad) < peso(cabeza.prioridad) do
      [necesidad | lista]
    else
      [cabeza | insertar_por_prioridad(cola, necesidad)]
    end
  end

  @doc "Ordena por prioridad usando `insertar_por_prioridad/2` (recursivo, estable)."
  @spec ordenar([t()]) :: [t()]
  def ordenar(necesidades), do: ordenar(necesidades, [])

  defp ordenar([], ordenadas), do: ordenadas

  defp ordenar([cabeza | cola], ordenadas),
    do: ordenar(cola, insertar_por_prioridad(ordenadas, cabeza))

  @doc """
  Filtra por `:zona`, `:tipo`, `:prioridad` y/o `:estado` (keyword list). Los
  valores pueden ser átomos o texto. Los filtros desconocidos se ignoran.
  """
  @spec filtrar([t()], keyword()) :: [t()]
  def filtrar(necesidades, filtros) do
    Enum.filter(necesidades, fn necesidad ->
      Enum.all?(filtros, fn {campo, valor} -> coincide?(necesidad, campo, valor) end)
    end)
  end

  defp coincide?(necesidad, campo, valor) when campo in [:zona, :tipo, :prioridad, :estado] do
    to_string(Map.get(necesidad, campo)) == to_string(valor)
  end

  defp coincide?(_necesidad, _campo, _valor), do: true
end
