defmodule Emergencias.Dominio.Zona do
  @moduledoc """
  Zona afectada (req. 1.4.3). Estructura JERÁRQUICA anidada:

      zona -> sectores -> puntos de atención

  `personas_estimadas` de cada nodo es la cantidad propia de ese nivel (no
  incluye la de sus hijos); el total acumulado se obtiene recorriendo el árbol.

  Funciones RECURSIVAS sobre el árbol (requisito obligatorio):

    * `total_afectados/1` - suma las personas de todo el árbol
    * `contar_puntos/1`   - cuenta los puntos de atención
    * `buscar_punto/2`    - búsqueda en profundidad por código
    * `estadisticas/1`    - usa las anteriores y cuenta sectores por nivel

  Las mismas funciones aceptan un nodo (`Zona`, `Sector`, `PuntoAtencion`) o una
  lista de nodos: el caso lista es la recursión cabeza/cola.
  """

  alias Emergencias.Dominio.{PuntoAtencion, Sector, Validaciones}

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

  @type nodo :: t() | Sector.t() | PuntoAtencion.t() | [Sector.t()] | [PuntoAtencion.t()]

  @doc "Crea una zona vacía (sin sectores) validando los datos."
  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(datos) when is_map(datos) do
    with {:ok, codigo} <- Validaciones.texto_no_vacio(Map.get(datos, :codigo)),
         {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre)),
         {:ok, nivel} <- Validaciones.nivel(Map.get(datos, :nivel)),
         {:ok, personas} <-
           Validaciones.entero_no_negativo_o(Map.get(datos, :personas_estimadas), 0) do
      {:ok,
       %__MODULE__{codigo: codigo, nombre: nombre, nivel: nivel, personas_estimadas: personas}}
    end
  end

  @doc "Cambia el nivel de afectación."
  @spec cambiar_nivel(t(), term()) :: {:ok, t()} | {:error, :nivel_invalido}
  def cambiar_nivel(%__MODULE__{} = zona, nivel) do
    with {:ok, nivel} <- Validaciones.nivel(nivel), do: {:ok, %{zona | nivel: nivel}}
  end

  @doc "Actualiza el número estimado de personas afectadas de la zona."
  @spec actualizar_personas(t(), term()) :: {:ok, t()} | {:error, :cantidad_invalida}
  def actualizar_personas(%__MODULE__{} = zona, personas) do
    with {:ok, n} <- Validaciones.entero_no_negativo(personas),
         do: {:ok, %{zona | personas_estimadas: n}}
  end

  @spec agregar_sector(t(), Sector.t()) :: {:ok, t()} | {:error, :sector_duplicado}
  def agregar_sector(%__MODULE__{sectores: sectores} = zona, %Sector{} = sector) do
    if Enum.any?(sectores, fn s -> s.codigo == sector.codigo end) do
      {:error, :sector_duplicado}
    else
      {:ok, %{zona | sectores: sectores ++ [sector]}}
    end
  end

  @spec agregar_punto(t(), String.t(), PuntoAtencion.t()) ::
          {:ok, t()} | {:error, :sector_no_existe | :punto_duplicado}
  def agregar_punto(%__MODULE__{} = zona, codigo_sector, %PuntoAtencion{} = punto) do
    with :ok <- punto_libre(zona, punto.codigo),
         {:ok, sector} <- buscar_sector(zona, codigo_sector) do
      actualizado = %{sector | puntos: sector.puntos ++ [punto]}

      sectores =
        Enum.map(zona.sectores, fn s ->
          if s.codigo == codigo_sector, do: actualizado, else: s
        end)

      {:ok, %{zona | sectores: sectores}}
    end
  end

  ## ---------------- RECURSIVAS sobre el árbol ----------------

  @doc "Suma recursiva de las personas afectadas de todo el árbol."
  @spec total_afectados(nodo()) :: non_neg_integer()
  def total_afectados(%__MODULE__{personas_estimadas: p, sectores: sectores}),
    do: p + total_afectados(sectores)

  def total_afectados(%Sector{personas_estimadas: p, puntos: puntos}),
    do: p + total_afectados(puntos)

  def total_afectados(%PuntoAtencion{personas_estimadas: p}), do: p
  def total_afectados([]), do: 0
  def total_afectados([cabeza | cola]), do: total_afectados(cabeza) + total_afectados(cola)

  @doc "Cuenta recursivamente los puntos de atención del árbol."
  @spec contar_puntos(nodo()) :: non_neg_integer()
  def contar_puntos(%__MODULE__{sectores: sectores}), do: contar_puntos(sectores)
  def contar_puntos(%Sector{puntos: puntos}), do: contar_puntos(puntos)
  def contar_puntos(%PuntoAtencion{}), do: 1
  def contar_puntos([]), do: 0
  def contar_puntos([cabeza | cola]), do: contar_puntos(cabeza) + contar_puntos(cola)

  @doc "Búsqueda en profundidad de un punto de atención por código."
  @spec buscar_punto(nodo(), String.t()) :: {:ok, PuntoAtencion.t()} | {:error, :no_encontrado}
  def buscar_punto(%__MODULE__{sectores: sectores}, codigo), do: buscar_punto(sectores, codigo)
  def buscar_punto(%Sector{puntos: puntos}, codigo), do: buscar_punto(puntos, codigo)
  def buscar_punto(%PuntoAtencion{codigo: codigo} = punto, codigo), do: {:ok, punto}
  def buscar_punto(%PuntoAtencion{}, _codigo), do: {:error, :no_encontrado}
  def buscar_punto([], _codigo), do: {:error, :no_encontrado}

  def buscar_punto([cabeza | cola], codigo) do
    case buscar_punto(cabeza, codigo) do
      {:ok, _punto} = encontrado -> encontrado
      {:error, :no_encontrado} -> buscar_punto(cola, codigo)
    end
  end

  @doc "Estadísticas acumuladas de la zona y sus sectores."
  @spec estadisticas(t()) :: map()
  def estadisticas(%__MODULE__{} = zona) do
    %{
      codigo: zona.codigo,
      nivel: zona.nivel,
      total_afectados: total_afectados(zona),
      sectores: length(zona.sectores),
      puntos: contar_puntos(zona),
      por_nivel: contar_niveles(zona.sectores, %{}),
      afectados_por_sector: Enum.map(zona.sectores, fn s -> {s.codigo, total_afectados(s)} end)
    }
  end

  # RECURSIVA con acumulador: cuántos sectores hay en cada nivel de afectación.
  defp contar_niveles([], acum), do: acum

  defp contar_niveles([%Sector{nivel: nivel} | cola], acum) do
    contar_niveles(cola, Map.update(acum, nivel, 1, fn n -> n + 1 end))
  end

  ## ---------------- privadas ----------------

  defp punto_libre(zona, codigo) do
    case buscar_punto(zona, codigo) do
      {:ok, _punto} -> {:error, :punto_duplicado}
      {:error, :no_encontrado} -> :ok
    end
  end

  defp buscar_sector(zona, codigo) do
    case Enum.find(zona.sectores, fn s -> s.codigo == codigo end) do
      nil -> {:error, :sector_no_existe}
      sector -> {:ok, sector}
    end
  end
end
