# Emergencias – Proyecto final Programación III (Elixir)

Sistema distribuido de coordinación y gestión de emergencias (terremoto).
**Estado actual: implementación completa** de los requisitos 1.4.1–1.4.10 (usuarios, zonas, necesidades, recursos con reserva concurrente, familiares, mascotas, albergues, persistencia y resumen). Falta solo lo que depende del equipo: datos de integrantes, video y enlace del repositorio. Demo del conflicto concurrente: `mix emergencias.demo`.

## Requisitos
Elixir ≥ 1.14 y Erlang/OTP. Sin dependencias externas.

## Uso
```bash
mix compile            # compilar
mix test               # pruebas (borra tmp/test_data antes de cada corrida)
mix emergencias.shell  # consola interactiva
mix emergencias.demo   # escenario del conflicto concurrente
iex -S mix             # para inspeccionar procesos (:observer.start())
```

## Documentación
* `docs/INFORME.md` – informe con las secciones del PDF (tablas e imágenes)
* `docs/DISENO.md` – decisiones de diseño
* `docs/PLAN_DESARROLLO.md` – orden de implementación
* `docs/diagramas/` – fuentes Mermaid (`.mmd`) y PNG
