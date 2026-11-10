defmodule Emergencias.Dominio.Mensaje do
  @moduledoc "Mensaje dirigido a una persona o familia (req. 1.4.6). Estados: `:pendiente | :entregado`."

  @enforce_keys [:id, :destinatario, :remitente, :contenido]
  defstruct [:id, :destinatario, :remitente, :contenido, :fecha, estado: :pendiente]

  @type t :: %__MODULE__{}

  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(_datos), do: {:error, :no_implementado}

  @spec marcar(t(), :entregado | :pendiente) :: {:ok, t()} | {:error, atom()}
  def marcar(_mensaje, _estado), do: {:error, :no_implementado}
end
