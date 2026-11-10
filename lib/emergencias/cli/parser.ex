defmodule Emergencias.Cli.Parser do
  @moduledoc """
  Convierte una línea de texto en un comando estructurado. Función pura.

      iex> Parser.parsear(~s(send_family_message 123 "Estoy bien, en el albergue"))
      {:ok, {:send_family_message, ["123", "Estoy bien, en el albergue"], []}}

      iex> Parser.parsear("list_needs zona=centro prioridad=critica")
      {:ok, {:list_needs, [], [zona: "centro", prioridad: "critica"]}}

  Argumentos posicionales -> lista; `clave=valor` -> keyword list. Las comillas
  dobles agrupan palabras. Comando desconocido -> `{:error, :comando_desconocido}`.
  """

  @comandos ~w(connect disconnect register_zone register_need list_needs assign_resource
               register_resource list_resources transfer_resource report_person find_person
               send_family_message list_family_messages report_pet match_pets register_shelter
               check_shelter register_entry register_exit summary critical_resources
               pending_needs help exit)a

  def comandos, do: @comandos

  @type comando :: {atom(), [String.t()], keyword()}

  @spec parsear(String.t()) :: {:ok, comando()} | {:error, atom()}
  def parsear(_linea), do: {:error, :no_implementado}

  @doc "Divide la línea en tokens respetando comillas (RECURSIVA sobre los caracteres)."
  @spec tokenizar(String.t()) :: {:ok, [String.t()]} | {:error, :comillas_sin_cerrar}
  def tokenizar(_linea), do: {:error, :no_implementado}
end
