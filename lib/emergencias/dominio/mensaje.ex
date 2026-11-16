defmodule Emergencias.Dominio.Mensaje do
  @moduledoc "Mensaje dirigido a una persona o familia (req. 1.4.6). Estados: `:pendiente | :entregado`."

  @enforce_keys [:id, :destinatario, :remitente, :contenido]
  defstruct [:id, :destinatario, :remitente, :contenido, :fecha, estado: :pendiente]

  @type t :: %__MODULE__{}

  @spec nuevo(map()) :: {:ok, t()} | {:error, atom()}
  def nuevo(datos) when is_map(datos) do
    id = datos[:id] || datos["id"]
    destinatario = datos[:destinatario] || datos["destinatario"]
    remitente = datos[:remitente] || datos["remitente"]
    contenido = datos[:contenido] || datos["contenido"]
    estado = datos[:estado] || datos["estado"] || :pendiente
    fecha = datos[:fecha] || datos["fecha"] || DateTime.utc_now() |> DateTime.truncate(:second)

    if id && destinatario && remitente && contenido do
      mensaje = %__MODULE__{
        id: id,
        destinatario: destinatario,
        remitente: remitente,
        contenido: contenido,
        fecha: fecha,
        estado: estado
      }

      {:ok, mensaje}
    else
      {:error, :datos_incompletos}
    end
  end

  @spec marcar(t(), :entregado | :pendiente) :: {:ok, t()} | {:error, atom()}
  def marcar(%__MODULE__{} = mensaje, nuevo_estado)
      when nuevo_estado in [:pendiente, :entregado] do
    {:ok, %{mensaje | estado: nuevo_estado}}
  end

  def marcar(%__MODULE__{}, _estado), do: {:error, :estado_invalido}
end
