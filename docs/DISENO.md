# Decisiones de diseño

## 1. Principios
1. **Dominio puro**: `Dominio.*` no usa procesos, archivos ni `IO`. Recibe datos y devuelve datos nuevos. Se prueba sin arrancar nada.
2. **Estado en procesos, reglas en el dominio**: un GenServer solo guarda el estado y llama a las funciones puras; la regla vive en el dominio.
3. **Sin excepciones para casos esperados**: toda función de dominio retorna `{:ok, valor}` o `{:error, razon_atom}`.
4. **Validar antes de modificar**: `Cli.Comandos` → `Validaciones` → servidor.
5. **Un proceso por recurso contendido**: la exclusión mutua la da el buzón del proceso, no candados.

## 2. Procesos independientes vs GenServer (enunciado 1.2)
| Elemento | Mecanismo | Razón |
|----------|-----------|-------|
| Usuarios, zonas, necesidades, personas/mensajes, mascotas | GenServer único | Estado compartido, baja contención |
| Recurso (inventario) | GenServer **por recurso** (DynamicSupervisor + Registry) | Alta contención: la misma existencia la piden varios |
| Albergue | GenServer **por albergue** | Capacidad máxima compartida |
| Bitácora | **Proceso puro** (`spawn_link`, `receive`, recursión) | Evidencia paso de mensajes sin OTP |
| Escritor | GenServer | Serializa escrituras a disco |
| Demo / consultas paralelas | `Task.Supervisor` | Concurrencia efímera |

## 3. Concurrencia: cómo se garantiza la regla obligatoria
* `RecursoServer.reservar/4` es una `GenServer.call`: el buzón ordena las solicitudes y cada una se evalúa sobre el inventario real → **imposible asignar más de lo existente**.
* Reserva **todo-o-nada** (si faltan unidades responde `{:error, :stock_insuficiente}` sin modificar nada).
* `NecesidadServer.registrar_asignacion/2` rechaza necesidades `:atendida`/`:cancelada`. Si falla tras reservar, `Asignador` llama a `liberar/4` (compensación).
* Transferencias entre centros ocurren dentro del mismo proceso del recurso (existencias por ubicación): atómicas, sin riesgo de interbloqueo.
* Un reporte de persona/mascota o una necesidad **no se cierra dos veces**: la transición se valida dentro del servidor (serializada) con `Estados.transicion/3` (estado terminal = sin salidas).
* `AlbergueServer` valida `ocupación < capacidad` dentro del proceso.

## 4. Supervisión
| Supervisor | Estrategia | Por qué |
|-----------|-----------|---------|
| `Emergencias.Supervisor` (raíz) | `one_for_one` | Subsistemas independientes |
| `Supervisores.Servidores` | `one_for_one` | Los 5 servidores no dependen entre sí |
| `Supervisores.Recursos` | `rest_for_one` | Si cae el DynamicSupervisor, el Restaurador debe correr de nuevo |
| `Supervisores.Albergues` | `rest_for_one` | Igual |
| Hijos de DynamicSupervisor | `restart: :transient` | Se reinician si caen anormalmente |

Recuperación: todo cambio se persiste; en `init/1` cada servidor relee su archivo.

## 5. Roles
Ver matriz en `Dominio.Permisos`. Propuesta: ciudadano (consulta y reportes), voluntario (+ ingresos a albergue, listar recursos), coordinador (+ registrar/asignar/transferir/resumen), administrador (todo).

## 6. Máquinas de estado
| Entidad | Transiciones válidas |
|---------|----------------------|
| Necesidad | pendiente→asignada→en_atencion→atendida; pendiente/asignada/en_atencion→cancelada |
| Persona | sin_informacion→reportada\|localizada; reportada→localizada; localizada→trasladada\|en_albergue\|reunificada; trasladada↔en_albergue; ambos→reunificada |
| Mascota | activa↔posible_coincidencia; ambos→resuelta |
| Mensaje | pendiente↔entregado |

## 7. Persistencia (texto plano)
Una línea por registro, campos separados por `|`, con escape. Ver tabla de archivos en `Persistencia.Almacen`. Las escrituras pasan por `Escritor` (un solo escritor ⇒ no hay líneas entrecruzadas).

## 8. Decisiones abiertas (acordar en equipo)
* Ajustes a los comandos del PDF: `report_person` sin edad (opcional `edad=`), `report_pet` sin características (opcional `caracteristicas=...`), `connect` solo usa tipo/zona al registrar.
* Ubicación → zona de un recurso: se toma de la zona del usuario que lo registra (campo `zona` del recurso).
* Prioridad: la cola de `pending_needs` se ordena crítica > alta > media > baja (y por antigüedad a igual prioridad).
* Pesos y umbral de `Similitud` (propuestos en el módulo).
* Asignación parcial vs todo-o-nada a nivel de necesidad (propuesto: todo-o-nada por llamada; la necesidad puede acumular varias).


## Concurrencia en la asignación (decisión final)

* Cada `RecursoServer` descuenta de forma atómica (un proceso por recurso).
* `Asignador` serializa las asignaciones de una misma categoría con `:global.trans/2`, para que dos solicitudes simultáneas no reserven parcialmente el mismo inventario y se estorben.
* La asignación es todo-o-nada: si no alcanza el stock o la necesidad rechaza el registro, se devuelve todo lo reservado (`RecursoServer.liberar/4`).
* Persistencia de recursos/albergues: tras cada cambio el cliente toma una foto de todos los procesos y reescribe el archivo dentro de un lock global (no se hace dentro del GenServer para evitar interbloqueos entre procesos).
