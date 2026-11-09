# Este repositorio es un fork

**rap77/openGym** es un fork personal de [DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym).
Todo el mérito del proyecto es de su autor. El README, el sitio web, las tiendas, los donativos y la comunidad (Discord) son del proyecto original.

## Qué añade este fork
- Supervisión de ejercicios por visión por computadora (en diseño): [docs/fork/DISENO-VISION.md](docs/fork/DISENO-VISION.md)
- Plan de mejoras: [docs/fork/PLAN-MEJORAS.md](docs/fork/PLAN-MEJORAS.md) · Línea base: [docs/fork/BASELINE.md](docs/fork/BASELINE.md)

## Relación con el upstream
- **Se sigue al upstream** (decisión D-0, 8-nov-2026): sync periódico desde `upstream/main`.
- Regla del fork: **no se editan archivos del upstream** si se puede evitar. Lo propio va en archivos nuevos (`FORK.md`, `docs/fork/`, código nuevo), y las funcionalidades útiles se proponen upstream como PR.
- Workflows de GitHub Actions que no aplican al fork: **desactivados desde GitHub**, no borrados ni editados (ver docs/fork/PLAN-MEJORAS.md, H1.1).

## Licencia
- Código: **AGPL-3.0-or-later**, igual que el original (ver `LICENSE`). Los cambios de este fork tienen la misma licencia.
- Medios del catálogo de ejercicios: licencia propia, ver `NOTICE.md` y `catalogue/media/NOTICE.md`.
- **Obligación AGPL §13:** si esta versión modificada se ofrece a otras personas por red, hay que darles acceso al código fuente de esta versión.
  - Estado actual: uso personal en local (`localhost`). No aplica todavía.
  - **Disparador:** el día que la instancia sea accesible por otra persona (Tailscale compartido, dominio público, cualquier usuario que no seas tú), antes de dar acceso se añade un enlace visible al código fuente de este fork (por ejemplo, en Ajustes → Acerca de) o se publica el repo con los cambios.
- `CLA.md` es el acuerdo de contribución del **proyecto original**. Aplica a los PR que se envíen upstream, no a este fork.
