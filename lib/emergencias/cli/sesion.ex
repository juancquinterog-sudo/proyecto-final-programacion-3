defmodule Emergencias.Cli.Sesion do
  @moduledoc "Estado de una sesión de consola: quién está conectado. Se pasa como argumento (sin estado global)."

  defstruct usuario: nil, tipo: nil, zona: nil

  @type t :: %__MODULE__{
          usuario: String.t() | nil,
          tipo: :ciudadano | :voluntario | :coordinador | :administrador | nil,
          zona: String.t() | nil
        }

  def anonima, do: %__MODULE__{}

  def conectada?(%__MODULE__{usuario: nil}), do: false
  def conectada?(%__MODULE__{}), do: true
end
