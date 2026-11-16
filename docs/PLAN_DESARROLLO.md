# Plan de desarrollo (orden sugerido)

Cada paso termina con `mix test` verde y el commit del que lo hizo (el PDF exige participación de todos en el repo).

| Fase | Qué implementar | Archivos | Pruebas a activar |
|------|-----------------|----------|-------------------|
| 0 | `mix compile` sin errores; crear repo | — | — |
| 1 | Validaciones, Estados, Permisos | `dominio/validaciones.ex`, `estados.ex`, `permisos.ex` | estados, permisos |
| 2 | Persistencia: Codec, Escritor, Almacen | `persistencia/*` | almacen |
| 3 | Dominio puro: Zona (recursivas), Necesidad, Recurso, Albergue | `dominio/*` | zona, necesidad, recurso, albergue |
| 4 | Parser + Shell + Comandos (solo connect) | `cli/*`, `usuario_server.ex` | parser, usuario |
| 5 | Servidores: Zona, Necesidad, Recurso, Albergue | `servidores/*`, `supervisores/*`, `restaurador.ex` | *_server |
| 6 | Asignador + conflicto concurrente | `servicios/asignador.ex` | asignador, recurso_server |
| 7 | Persona, Mensaje, Mascota + Similitud | `dominio/*`, `persona_server.ex`, `mascota_server.ex` | similitud, mascota_server |
| 8 | Resumen y reportes | `servicios/resumen.ex`, `estadisticas.ex` | estadisticas |
| 9 | Bitácora | `procesos/bitacora.ex` | — |
| 10 | Demo, video, revisar diagramas vs código | `mix/tasks/emergencias.demo.ex`, `docs/` | todo |

Al terminar: regenerar los diagramas si cambió algo
(`mmdc -i docs/diagramas/otp.mmd -o docs/diagramas/otp.png -s 2 -b white`).

## Convenciones
* Nombres de módulos y funciones en español, igual que en tus apuntes.
* Funciones de dominio: `{:ok, _} | {:error, atom}`; nunca `raise` para casos esperados.
* `|>` y pattern matching en lugar de `if` anidados.
* Los `@spec` y `@moduledoc` ya están puestos: mantenerlos actualizados.
