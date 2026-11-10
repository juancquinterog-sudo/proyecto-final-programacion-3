defmodule Emergencias.Dominio.Recurso do
  @moduledoc """
  Recurso e inventario (req. 1.4.5). Módulo puro: cada función recibe un
  `Recurso` y devuelve otro NUEVO (inmutabilidad). La exclusión mutua real la
  da `Servidores.RecursoServer` (un proceso por recurso).

  El inventario se guarda por ubicación en un mapa:
  `existencias: %{"centro_acopio_1" => 50}`. Una transferencia entre centros es
  así una operación atómica dentro de UN solo valor.

  El `historial` guarda los movimientos con el MÁS RECIENTE primero. Cada
  operación recibe un mapa `meta` con `:usuario`, `:fecha` y `:referencia`
  (opcionales; la fecha la aporta quien llama para mantener el módulo puro).

  Reglas: las cantidades son enteros positivos; el stock nunca queda negativo
  (`{:error, :stock_insuficiente}` y el recurso queda igual).
  """

  alias Emergencias.Dominio.{Movimiento, Validaciones}

  @enforce_keys [:codigo, :nombre, :categoria, :unidad]
  defstruct [:codigo, :nombre, :categoria, :unidad, :zona, existencias: %{}, historial: []]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          categoria: atom(),
          unidad: String.t(),
          zona: String.t() | nil,
          existencias: %{String.t() => non_neg_integer()},
          historial: [Movimiento.t()]
        }

  @doc """
  Crea un recurso. `datos`: `:codigo`, `:nombre`, `:categoria`, `:unidad`
  (obligatorios); `:zona`, `:cantidad` y `:ubicacion` (opcionales). Si hay
  `:cantidad` > 0 se registra como una entrada inicial en `:ubicacion`.
  """
  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    with {:ok, codigo} <- Validaciones.texto_no_vacio(Map.get(datos, :codigo)),
         {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre)),
         {:ok, categoria} <- Validaciones.tipo_necesidad(Map.get(datos, :categoria)),
         {:ok, unidad} <- Validaciones.texto_no_vacio(Map.get(datos, :unidad)),
         {:ok, cantidad} <- Validaciones.entero_no_negativo_o(Map.get(datos, :cantidad), 0) do
      base = %__MODULE__{
        codigo: codigo,
        nombre: nombre,
        categoria: categoria,
        unidad: unidad,
        zona: Map.get(datos, :zona)
      }

      inicial(base, Map.get(datos, :ubicacion), cantidad, datos)
    end
  end

  defp inicial(recurso, _ubicacion, 0, _meta), do: {:ok, recurso}
  defp inicial(recurso, ubicacion, cantidad, meta), do: entrada(recurso, ubicacion, cantidad, meta)

  @spec disponible(t(), String.t()) :: non_neg_integer()
  def disponible(%__MODULE__{existencias: e}, ubicacion), do: Map.get(e, ubicacion, 0)

  @spec total(t()) :: non_neg_integer()
  def total(%__MODULE__{existencias: e}), do: e |> Map.values() |> Enum.sum()

  @doc "Ubicaciones con stock, de mayor a menor cantidad (útil para asignar)."
  @spec con_stock(t()) :: [{String.t(), pos_integer()}]
  def con_stock(%__MODULE__{existencias: e}) do
    e
    |> Enum.filter(fn {_ubicacion, cantidad} -> cantidad > 0 end)
    |> Enum.sort_by(fn {ubicacion, cantidad} -> {-cantidad, ubicacion} end)
  end

  @spec entrada(t(), String.t(), pos_integer(), map()) :: {:ok, t()} | {:error, atom()}
  def entrada(%__MODULE__{} = recurso, ubicacion, cantidad, meta) do
    with {:ok, ubicacion} <- ubicacion_valida(ubicacion),
         {:ok, cantidad} <- Validaciones.entero_positivo(cantidad) do
      {:ok, mover(recurso, ubicacion, cantidad, :entrada, meta)}
    end
  end

  @spec salida(t(), String.t(), pos_integer(), map()) ::
          {:ok, t()} | {:error, :stock_insuficiente | atom()}
  def salida(%__MODULE__{} = recurso, ubicacion, cantidad, meta),
    do: retirar(recurso, ubicacion, cantidad, :salida, meta)

  @doc "Descuenta stock para una necesidad (movimiento `:asignacion` con la referencia)."
  @spec asignar(t(), String.t(), pos_integer(), String.t(), map()) ::
          {:ok, t()} | {:error, :stock_insuficiente | atom()}
  def asignar(%__MODULE__{} = recurso, ubicacion, cantidad, id_necesidad, meta),
    do: retirar(recurso, ubicacion, cantidad, :asignacion, Map.put(meta, :referencia, id_necesidad))

  @spec transferir(t(), String.t(), String.t(), pos_integer(), map()) ::
          {:ok, t()} | {:error, atom()}
  def transferir(%__MODULE__{} = recurso, origen, destino, cantidad, meta) do
    with {:ok, origen} <- ubicacion_valida(origen),
         {:ok, destino} <- ubicacion_valida(destino),
         :ok <- distintas(origen, destino),
         {:ok, cantidad} <- Validaciones.entero_positivo(cantidad),
         :ok <- hay_stock(recurso, origen, cantidad) do
      {:ok,
       recurso
       |> mover(origen, -cantidad, :transferencia_salida, meta)
       |> mover(destino, cantidad, :transferencia_entrada, meta)}
    end
  end

  ## ---------------- privadas ----------------

  defp retirar(recurso, ubicacion, cantidad, tipo, meta) do
    with {:ok, ubicacion} <- ubicacion_valida(ubicacion),
         {:ok, cantidad} <- Validaciones.entero_positivo(cantidad),
         :ok <- hay_stock(recurso, ubicacion, cantidad) do
      {:ok, mover(recurso, ubicacion, -cantidad, tipo, meta)}
    end
  end

  # Aplica un cambio (+/-) a una ubicación y registra el movimiento (el más reciente primero).
  defp mover(recurso, ubicacion, delta, tipo, meta) do
    movimiento = %Movimiento{
      codigo_recurso: recurso.codigo,
      tipo: tipo,
      cantidad: abs(delta),
      ubicacion: ubicacion,
      referencia: Map.get(meta, :referencia),
      usuario: Map.get(meta, :usuario),
      fecha: Map.get(meta, :fecha)
    }

    %{
      recurso
      | existencias: Map.update(recurso.existencias, ubicacion, delta, fn actual -> actual + delta end),
        historial: [movimiento | recurso.historial]
    }
  end

  defp hay_stock(recurso, ubicacion, cantidad) do
    if disponible(recurso, ubicacion) >= cantidad, do: :ok, else: {:error, :stock_insuficiente}
  end

  defp distintas(origen, destino) do
    if origen == destino, do: {:error, :misma_ubicacion}, else: :ok
  end

  defp ubicacion_valida(ubicacion) do
    case Validaciones.texto_no_vacio(ubicacion) do
      {:ok, texto} -> {:ok, texto}
      {:error, _} -> {:error, :ubicacion_invalida}
    end
  end
end
