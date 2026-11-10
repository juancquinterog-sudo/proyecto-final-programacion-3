defmodule Emergencias.Cli.Parser do
  @moduledoc """
  Convierte una línea de texto en un comando estructurado. Función pura.

      iex> Parser.parsear(~s(send_family_message 123 "Estoy bien, en el albergue"))
      {:ok, {:send_family_message, ["123", "Estoy bien, en el albergue"], []}}

      iex> Parser.parsear("list_needs zona=centro prioridad=critica")
      {:ok, {:list_needs, [], [zona: "centro", prioridad: "critica"]}}

  * Argumentos posicionales -> lista de textos.
  * `clave=valor` -> keyword list, solo para claves conocidas (`zona`, `tipo`,
    `prioridad`, `estado`, `edad`, `caracteristicas`, `nombre`); cualquier otro
    texto con `=` se trata como argumento normal.
  * Las comillas dobles agrupan palabras (`zona="zona norte"` es válido).
  * El nombre del comando no distingue mayúsculas.
  """

  @comandos ~w(connect disconnect register_zone register_need list_needs assign_resource
               register_resource list_resources transfer_resource report_person find_person
               send_family_message list_family_messages report_pet match_pets register_shelter
               check_shelter register_entry register_exit summary critical_resources
               pending_needs help exit)a

  @opciones %{
    "zona" => :zona,
    "tipo" => :tipo,
    "prioridad" => :prioridad,
    "estado" => :estado,
    "edad" => :edad,
    "caracteristicas" => :caracteristicas,
    "nombre" => :nombre
  }

  def comandos, do: @comandos

  @type comando :: {atom(), [String.t()], keyword()}

  @spec parsear(String.t()) :: {:ok, comando()} | {:error, atom()}
  def parsear(linea) when is_binary(linea) do
    with {:ok, tokens} <- tokenizar(linea) do
      case tokens do
        [] ->
          {:error, :comando_vacio}

        [nombre | resto] ->
          case buscar_comando(nombre) do
            {:ok, comando} ->
              {argumentos, opciones} = separar(resto, [], [])
              {:ok, {comando, argumentos, opciones}}

            :error ->
              {:error, :comando_desconocido}
          end
      end
    end
  end

  @doc """
  Divide la línea en tokens respetando comillas (RECURSIVA sobre los caracteres).
  Las comillas no forman parte del token; `""` produce un token vacío.
  """
  @spec tokenizar(String.t()) :: {:ok, [String.t()]} | {:error, :comillas_sin_cerrar}
  def tokenizar(linea) when is_binary(linea), do: tokenizar(linea, "", [], false, false)

  # tokenizar(resto, token_actual, tokens_acumulados, dentro_de_comillas?, hay_token?)
  defp tokenizar("", _actual, _acum, true, _hay), do: {:error, :comillas_sin_cerrar}

  defp tokenizar("", actual, acum, false, hay),
    do: {:ok, Enum.reverse(cerrar(actual, acum, hay))}

  defp tokenizar(<<"\"", resto::binary>>, actual, acum, en_comillas, _hay),
    do: tokenizar(resto, actual, acum, not en_comillas, true)

  defp tokenizar(<<c::utf8, resto::binary>>, actual, acum, false, hay)
       when c in [?\s, ?\t, ?\n, ?\r],
       do: tokenizar(resto, "", cerrar(actual, acum, hay), false, false)

  defp tokenizar(<<c::utf8, resto::binary>>, actual, acum, en_comillas, _hay),
    do: tokenizar(resto, actual <> <<c::utf8>>, acum, en_comillas, true)

  defp tokenizar(<<b, resto::binary>>, actual, acum, en_comillas, _hay),
    do: tokenizar(resto, actual <> <<b>>, acum, en_comillas, true)

  defp cerrar(actual, acum, true), do: [actual | acum]
  defp cerrar(_actual, acum, false), do: acum

  defp buscar_comando(nombre) do
    minuscula = String.downcase(nombre)

    case Enum.find(@comandos, fn comando -> Atom.to_string(comando) == minuscula end) do
      nil -> :error
      comando -> {:ok, comando}
    end
  end

  # RECURSIVA: reparte los tokens entre argumentos posicionales y opciones clave=valor.
  defp separar([], argumentos, opciones),
    do: {Enum.reverse(argumentos), Enum.reverse(opciones)}

  defp separar([token | cola], argumentos, opciones) do
    case opcion(token) do
      {:ok, par} -> separar(cola, argumentos, [par | opciones])
      :error -> separar(cola, [token | argumentos], opciones)
    end
  end

  defp opcion(token) do
    with [clave, valor] <- String.split(token, "=", parts: 2),
         {:ok, atomo} <- Map.fetch(@opciones, clave) do
      {:ok, {atomo, valor}}
    else
      _ -> :error
    end
  end
end
