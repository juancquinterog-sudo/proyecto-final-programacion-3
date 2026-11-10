defmodule Emergencias.Supervisores.Albergues do
  @moduledoc """
  Subárbol de albergues: un `DynamicSupervisor` (un `AlbergueServer` por
  albergue) y un `Restaurador` que recrea los procesos desde `albergues.txt`.
  Misma estrategia `:rest_for_one` que `Supervisores.Recursos`.
  """
  use Supervisor

  def start_link(_arg), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: Emergencias.AlbergueDinamico, strategy: :one_for_one},
      {Emergencias.Persistencia.Restaurador, :albergues}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
