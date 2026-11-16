defmodule Emergencias.Application do
  @moduledoc """
  Aplicación OTP. Levanta el árbol de supervisión (ver docs/diagramas/otp.png).

  Orden de arranque (importa porque los hijos dependen de los anteriores):

    1. `Persistencia.Escritor`  - único proceso que escribe en disco
    2. `Registry`               - nombres dinámicos ({:recurso, codigo}, {:albergue, codigo})
    3. `Procesos.Bitacora`      - proceso puro que registra la actividad de usuarios
    4. `Task.Supervisor`        - tareas concurrentes (simulaciones, pruebas de carga)
    5. `Supervisores.Servidores`- GenServers estáticos (usuarios, zonas, necesidades, ...)
    6. `Supervisores.Recursos`  - DynamicSupervisor: un proceso por recurso
    7. `Supervisores.Albergues` - DynamicSupervisor: un proceso por albergue
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Emergencias.Persistencia.Escritor,
      {Registry, keys: :unique, name: Emergencias.Registry},
      Emergencias.Procesos.Bitacora,
      {Task.Supervisor, name: Emergencias.TareaSupervisor},
      Emergencias.Supervisores.Servidores,
      Emergencias.Supervisores.Recursos,
      Emergencias.Supervisores.Albergues
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Emergencias.Supervisor)
  end
end
