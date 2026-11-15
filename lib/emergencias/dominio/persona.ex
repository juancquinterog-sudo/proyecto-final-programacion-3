defmodule Emergencias.Dominio.Persona do
  @moduledoc """
  Persona afectada (req. 1.4.6). Conserva el HISTORIAL de cambios de estado como
  lista de tuplas `{estado, fecha, usuario}` (el más reciente primero).

  Estados: `:sin_informacion | :reportada | :localizada | :trasladada |
  :en_albergue | :reunificada`.
  """

  @enforce_keys [:documento, :nombre, :zona, :estado]
  defstruct [:id, :documento, :nombre, :edad, :zona, :estado, :albergue, historial: []]

  @type t :: %__MODULE__{}

  @spec nueva(map()) :: {:ok, t()} | {:error, atom()}
  def nueva(datos) when is_map(datos) do
    documento = datos[:documento] || datos["documento"]
    nombre = datos[:nombre] || datos["nombre"]
    zona = datos[:zona] || datos["zona"]
    estado = datos[:estado] || datos["estado"] || :sin_informacion

    if documento && nombre && zona do
      id = datos[:id] || datos["id"] || documento
      persona = %__MODULE__{
        id: id,
        documento: documento,
        nombre: nombre,
        edad: datos[:edad] || datos["edad"],
        zona: zona,
        estado: estado,
        albergue: datos[:albergue] || datos["albergue"],
        historial: [{estado, NaiveDateTime.utc_now(), "sistema"}]
      }
      {:ok, persona}
    else
      {:error, :datos_incompletos}
    end
  end

  @spec cambiar_estado(t(), atom(), String.t()) :: {:ok, t()} | {:error, atom()}
  def cambiar_estado(%__MODULE__{} = persona, nuevo_estado, usuario) when is_atom(nuevo_estado) and is_binary(usuario) do
    nuevo_historial = [{nuevo_estado, NaiveDateTime.utc_now(), usuario} | persona.historial]
    persona_actualizada = %{persona | estado: nuevo_estado, historial: nuevo_historial}
    {:ok, persona_actualizada}
  end
  def cambiar_estado(%__MODULE__{}, _, _), do: {:error, :datos_invalidos}

  @doc "Búsqueda por nombre (contiene), documento, zona o estado. `filtros` = keyword."
  @spec buscar([t()], keyword()) :: [t()]
  def buscar(personas, filtros) when is_list(personas) and is_list(filtros) do
    Enum.filter(personas, fn persona ->
      Enum.all?(filtros, fn {clave, valor} ->
        case clave do
          :nombre ->
            String.contains?(String.downcase(persona.nombre || ""), String.downcase(to_string(valor)))
          :documento ->
            to_string(persona.documento) == to_string(valor)
          :zona ->
            persona.zona == valor
          :estado ->
            persona.estado == valor
          _ ->
            true
        end
      end)
    end)
  end
  def buscar(personas, _), do: personas
end
