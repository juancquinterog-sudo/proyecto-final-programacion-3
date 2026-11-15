defmodule Emergencias.Dominio.MensajeTest do
  use ExUnit.Case, async: true
  alias Emergencias.Dominio.Mensaje

  test "crear struct de mensaje" do
    msg = %Mensaje{id: "MSG1", contenido: "Necesito víveres", remitente: "Carlos"}
    assert msg.contenido == "Necesito víveres"
  end
end
