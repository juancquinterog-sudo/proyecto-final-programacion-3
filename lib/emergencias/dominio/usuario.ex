defmodule Emergencias.Dominio.Usuario do
  @moduledoc """
  Usuario del sistema (req. 1.4.1 y 1.4.2). Módulo PURO: no usa procesos ni archivos.

  Tipos: `:ciudadano | :voluntario | :coordinador | :administrador`.
  La contraseña se guarda como hash SHA-256 (nunca en claro).
  """

  alias Emergencias.Dominio.Validaciones

  @tipos [:ciudadano, :voluntario, :coordinador, :administrador]

  @enforce_keys [:nombre_usuario, :hash_contrasena, :tipo]
  defstruct [:nombre_usuario, :hash_contrasena, :nombre_completo, :tipo, :zona]

  @type tipo :: :ciudadano | :voluntario | :coordinador | :administrador
  @type t :: %__MODULE__{
          nombre_usuario: String.t(),
          hash_contrasena: String.t(),
          nombre_completo: String.t() | nil,
          tipo: tipo(),
          zona: String.t() | nil
        }

  def tipos, do: @tipos

  @doc """
  Crea un usuario validando los datos. `datos` es un mapa con las claves
  `:nombre_usuario`, `:contrasena`, `:tipo` y opcionalmente `:nombre_completo` y `:zona`.
  """
  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    with {:ok, nombre} <- Validaciones.texto_no_vacio(Map.get(datos, :nombre_usuario)),
         {:ok, contrasena} <- Validaciones.texto_no_vacio(Map.get(datos, :contrasena)),
         {:ok, tipo} <- Validaciones.tipo_usuario(Map.get(datos, :tipo)) do
      {:ok,
       %__MODULE__{
         nombre_usuario: nombre,
         hash_contrasena: hash(contrasena),
         nombre_completo: Map.get(datos, :nombre_completo) || nombre,
         tipo: tipo,
         zona: Map.get(datos, :zona)
       }}
    end
  end

  @doc "Calcula el hash SHA-256 (hex) de una contraseña."
  @spec hash(String.t()) :: String.t()
  def hash(contrasena) do
    :crypto.hash(:sha256, contrasena) |> Base.encode16(case: :lower)
  end

  @doc "Valida la contraseña de un usuario existente."
  @spec autenticar(t(), String.t()) :: :ok | {:error, :credenciales_invalidas}
  def autenticar(%__MODULE__{hash_contrasena: h}, contrasena) do
    if h == hash(contrasena), do: :ok, else: {:error, :credenciales_invalidas}
  end
end
