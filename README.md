# Emergencias – Proyecto final Programación III (Elixir)

Sistema distribuido de coordinación y gestión de emergencias (terremoto).
**Estado actual: esqueleto de arquitectura** (módulos, structs, supervisión, docs y pruebas pendientes). La lógica se implementa siguiendo `docs/PLAN_DESARROLLO.md`.

## Requisitos
Elixir ≥ 1.14 y Erlang/OTP. Sin dependencias externas.

## Uso
```bash
mix compile            # compilar
mix test               # pruebas (las pendientes están en @moduletag :skip)
mix emergencias.shell  # consola interactiva
mix emergencias.demo   # escenario del conflicto concurrente
iex -S mix             # para inspeccionar procesos (:observer.start())
```

## Documentación
* `docs/INFORME.md` – informe con las secciones del PDF (tablas e imágenes)
* `docs/DISENO.md` – decisiones de diseño
* `docs/PLAN_DESARROLLO.md` – orden de implementación
* `docs/diagramas/` – fuentes Mermaid (`.mmd`) y PNG
