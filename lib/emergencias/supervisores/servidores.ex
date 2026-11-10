defmodule Emergencias.Supervisores.Servidores do
  @moduledoc """
  Supervisor de los GenServer "estáticos" (una sola instancia por sistema).

  Estrategia `:one_for_one`: cada servidor es independiente; si uno falla se
  reinicia solo y recupera su estado leyendo su archivo de texto plano.
  """
  use Supervisor

  def start_link(_arg), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    children = [
      Emergencias.Servidores.UsuarioServer,
      Emergencias.Servidores.ZonaServer,
      Emergencias.Servidores.NecesidadServer,
      Emergencias.Servidores.PersonaServer,
      Emergencias.Servidores.MascotaServer
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 5)
  end
end
