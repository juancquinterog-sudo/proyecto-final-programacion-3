defmodule Emergencias.Dominio.PuntoAtencion do
  @moduledoc "Punto de atención (hoja del árbol zona -> sector -> punto)."

  alias Emergencias.Dominio.Validaciones

  @enforce_keys [:codigo, :nombre]
  defstruct [:codigo, :nombre, personas_estimadas: 0]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          personas_estimadas: non_neg_integer()
        }

  @doc "Crea un punto validando los datos (`:codigo`, `:nombre`, `:personas_estimadas` opcional)."
  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    with {:ok, codigo} <- Validaciones.texto_no_vacio(Map.get(datos, :codigo)),
         {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre)),
         {:ok, personas} <-
           Validaciones.entero_no_negativo_o(Map.get(datos, :personas_estimadas), 0) do
      {:ok, %__MODULE__{codigo: codigo, nombre: nombre, personas_estimadas: personas}}
    end
  end
end
