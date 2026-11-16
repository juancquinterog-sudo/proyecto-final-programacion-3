defmodule Emergencias.Dominio.Validaciones do
  @moduledoc """
  Validación de entradas del usuario ANTES de modificar el estado (req. 1.4.9).
  Todas las funciones retornan `{:ok, valor_normalizado} | {:error, razon}`.

  Aceptan tanto el tipo final (entero, átomo) como texto, porque lo que llega
  de la consola siempre es `String`.
  """

  alias Emergencias.Dominio.Estados

  @prioridades %{
    "critica" => :critica,
    "crítica" => :critica,
    "alta" => :alta,
    "media" => :media,
    "baja" => :baja
  }

  @niveles %{
    "critico" => :critico,
    "crítico" => :critico,
    "alto" => :alto,
    "medio" => :medio,
    "bajo" => :bajo
  }

  @tipos_necesidad %{
    "agua" => :agua,
    "alimentos" => :alimentos,
    "medicamentos" => :medicamentos,
    "primeros_auxilios" => :primeros_auxilios,
    "refugio" => :refugio,
    "transporte" => :transporte,
    "rescate" => :rescate,
    "otra" => :otra,
    "otro" => :otra
  }

  @tipos_usuario %{
    "ciudadano" => :ciudadano,
    "voluntario" => :voluntario,
    "coordinador" => :coordinador,
    "coordinadora" => :coordinador,
    "administrador" => :administrador
  }

  @tipos_reporte %{
    "lost" => :perdida,
    "perdida" => :perdida,
    "found" => :encontrada,
    "encontrada" => :encontrada
  }

  @spec entero_positivo(term()) :: {:ok, pos_integer()} | {:error, :cantidad_invalida}
  def entero_positivo(valor) do
    case a_entero(valor) do
      {:ok, n} when n > 0 -> {:ok, n}
      _ -> {:error, :cantidad_invalida}
    end
  end

  @spec entero_no_negativo(term()) :: {:ok, non_neg_integer()} | {:error, :cantidad_invalida}
  def entero_no_negativo(valor) do
    case a_entero(valor) do
      {:ok, n} when n >= 0 -> {:ok, n}
      _ -> {:error, :cantidad_invalida}
    end
  end

  @spec texto_no_vacio(term()) :: {:ok, String.t()} | {:error, :texto_vacio}
  def texto_no_vacio(valor) when is_binary(valor) do
    case String.trim(valor) do
      "" -> {:error, :texto_vacio}
      texto -> {:ok, texto}
    end
  end

  def texto_no_vacio(_valor), do: {:error, :texto_vacio}

  @spec prioridad(term()) :: {:ok, :critica | :alta | :media | :baja} | {:error, :prioridad_invalida}
  def prioridad(valor), do: buscar(valor, @prioridades, :prioridad_invalida)

  @spec nivel(term()) :: {:ok, :critico | :alto | :medio | :bajo} | {:error, :nivel_invalido}
  def nivel(valor), do: buscar(valor, @niveles, :nivel_invalido)

  @spec tipo_necesidad(term()) :: {:ok, atom()} | {:error, :tipo_invalido}
  def tipo_necesidad(valor), do: buscar(valor, @tipos_necesidad, :tipo_invalido)

  @spec tipo_usuario(term()) :: {:ok, atom()} | {:error, :tipo_usuario_invalido}
  def tipo_usuario(valor), do: buscar(valor, @tipos_usuario, :tipo_usuario_invalido)

  @doc "Tipo de reporte de mascota: acepta lost/found o perdida/encontrada."
  @spec tipo_reporte(term()) :: {:ok, :perdida | :encontrada} | {:error, :tipo_reporte_invalido}
  def tipo_reporte(valor), do: buscar(valor, @tipos_reporte, :tipo_reporte_invalido)

  @doc "Estado válido para una entidad (`:necesidad`, `:persona`, `:mascota`, `:mensaje`)."
  @spec estado(atom(), term()) :: {:ok, atom()} | {:error, :estado_invalido}
  def estado(entidad, valor) do
    texto = normalizar(valor)

    case Enum.find(Estados.estados(entidad), fn e -> Atom.to_string(e) == texto end) do
      nil -> {:error, :estado_invalido}
      encontrado -> {:ok, encontrado}
    end
  end

  @doc "Verifica que un identificador no exista. `existentes` = lista o MapSet de ids (usar `Map.keys/1` si es un mapa)."
  @spec id_libre?(String.t(), Enumerable.t()) :: :ok | {:error, :id_duplicado}
  def id_libre?(id, existentes) do
    if Enum.member?(existentes, id), do: {:error, :id_duplicado}, else: :ok
  end

  ## Privadas

  defp a_entero(n) when is_integer(n), do: {:ok, n}

  defp a_entero(texto) when is_binary(texto) do
    case Integer.parse(String.trim(texto)) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp a_entero(_otro), do: :error

  defp buscar(valor, mapa, error) do
    case Map.fetch(mapa, normalizar(valor)) do
      {:ok, encontrado} -> {:ok, encontrado}
      :error -> {:error, error}
    end
  end

  defp normalizar(valor) when is_atom(valor) and not is_nil(valor),
    do: valor |> Atom.to_string() |> normalizar()

  defp normalizar(valor) when is_binary(valor) do
    valor |> String.trim() |> String.downcase() |> String.replace([" ", "-"], "_")
  end

  defp normalizar(_otro), do: ""
end
