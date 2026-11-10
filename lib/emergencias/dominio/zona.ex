defmodule Emergencias.Dominio.Zona do
  @moduledoc """
  Zona afectada (req. 1.4.3). Estructura JERÁRQUICA anidada:

      zona -> sectores -> puntos de atención

  Aquí viven las funciones RECURSIVAS sobre el árbol (requisito obligatorio):

    * `total_afectados/1`  - suma recursiva de personas afectadas del árbol
    * `contar_puntos/1`    - cuenta recursivamente los puntos de atención
    * `buscar_punto/2`     - búsqueda recursiva en profundidad por código
    * `estadisticas/1`     - acumula por nivel de afectación recorriendo el árbol

  Los albergues, necesidades, recursos y reportes se asocian por `codigo` de
  zona (no se anidan dentro de la zona; viven en sus propios servidores).
  """

  alias Emergencias.Dominio.{Sector, PuntoAtencion}

  @enforce_keys [:codigo, :nombre, :nivel]
  defstruct [:codigo, :nombre, :nivel, personas_estimadas: 0, sectores: []]

  @type nivel :: :critico | :alto | :medio | :bajo
  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          nivel: nivel(),
          personas_estimadas: non_neg_integer(),
          sectores: [Sector.t()]
        }

  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(_datos), do: {:error, :no_implementado}

  @spec agregar_sector(t(), Sector.t()) :: {:ok, t()} | {:error, atom()}
  def agregar_sector(_zona, _sector), do: {:error, :no_implementado}

  @spec agregar_punto(t(), String.t(), PuntoAtencion.t()) :: {:ok, t()} | {:error, atom()}
  def agregar_punto(_zona, _codigo_sector, _punto), do: {:error, :no_implementado}

  # --- RECURSIVAS (TODO: implementar con recursión de cabeza/cola, sin Enum.reduce) ---

  @spec total_afectados(t() | Sector.t() | [Sector.t()]) :: non_neg_integer()
  def total_afectados(_nodo), do: 0

  @spec contar_puntos(t() | Sector.t() | [Sector.t()]) :: non_neg_integer()
  def contar_puntos(_nodo), do: 0

  @spec buscar_punto(t() | [Sector.t()] | [PuntoAtencion.t()], String.t()) ::
          {:ok, PuntoAtencion.t()} | {:error, :no_encontrado}
  def buscar_punto(_nodo, _codigo), do: {:error, :no_implementado}

  @spec estadisticas(t()) :: %{atom() => term()}
  def estadisticas(_zona), do: %{}
end
