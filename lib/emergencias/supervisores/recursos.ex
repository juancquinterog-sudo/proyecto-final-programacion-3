defmodule Emergencias.Supervisores.Recursos do
  @moduledoc """
  Subárbol de recursos: un `DynamicSupervisor` (un `RecursoServer` por código
  de recurso) y un `Restaurador` que, al arrancar, relee `recursos.txt` y crea
  los procesos.

  Estrategia `:rest_for_one`: si el DynamicSupervisor muere, se pierden sus
  hijos y por eso el Restaurador (declarado después) se vuelve a ejecutar.
  """
  use Supervisor

  def start_link(_arg), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: Emergencias.RecursoDinamico, strategy: :one_for_one},
      {Emergencias.Persistencia.Restaurador, :recursos}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
