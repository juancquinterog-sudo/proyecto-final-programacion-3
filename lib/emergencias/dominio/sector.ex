defmodule Emergencias.Dominio.Sector do
  @moduledoc "Sector dentro de una zona. Contiene puntos de atención (nivel intermedio del árbol)."
  alias Emergencias.Dominio.{PuntoAtencion, Validaciones}

  @enforce_keys [:codigo, :nombre]
  defstruct [:codigo, :nombre, nivel: :medio, personas_estimadas: 0, puntos: []]

  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          nivel: :critico | :alto | :medio | :bajo,
          personas_estimadas: non_neg_integer(),
          puntos: [PuntoAtencion.t()]
        }

  @doc "Crea un sector validando los datos. El nivel por defecto es `:medio`."
  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    with {:ok, codigo} <- Validaciones.texto_no_vacio(Map.get(datos, :codigo)),
         {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre)),
         {:ok, nivel} <- Validaciones.nivel(Map.get(datos, :nivel) || :medio),
         {:ok, personas} <-
           Validaciones.entero_no_negativo_o(Map.get(datos, :personas_estimadas), 0) do
      {:ok, %__MODULE__{codigo: codigo, nombre: nombre, nivel: nivel, personas_estimadas: personas}}
    end
  end
end
