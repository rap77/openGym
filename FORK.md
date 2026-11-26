# Este repositorio es un fork

**rap77/openGym** es un fork personal de [DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym).
Todo el mérito del proyecto es de su autor. El README, el sitio web, las tiendas, los donativos y la comunidad (Discord) son del proyecto original.

## Qué añade este fork
- **Tus rutinas de entrenamiento**, escritas en el formato de plan que openGym ya lee:
  [fork-routines/](fork-routines/README.md). Ahora mismo: Atlas (el método de Charles Atlas:
  10 series, progresión doble y tempo de 4 cifras), movilidad diaria e hipopresivos.
  **32 ejercicios, todos con vídeo e instrucciones en español en el catálogo.**
  La importación está automatizada: `e2e/tests/04-import-plan.spec.js` lo mete en la app real y
  comprueba que la regla de progresión y el tempo llegan a la rutina.
- Supervisión de ejercicios por visión por computadora (en diseño): [docs/fork/DISENO-VISION.md](docs/fork/DISENO-VISION.md)
- **Biblioteca propia de rutinas** (en curso): el upstream 1.4.5 abrió su biblioteca de rutinas como un índice
  JSON configurable por instancia (`config.coach.routinesUrl`, en Ajustes → AI Coach → Advanced → Routines
  library). El fork puede publicar ahí sus propias rutinas sin tocar un solo fichero del upstream.
  **Ojo:** ese formato es de descubrimiento, no de prescripción: `entryToBundle` descarta la progresión y el
  tempo. Para rutinas *con método* (progresión, tempo) el vehículo es el plan file. Ver
  [docs/fork/PLAN-MEJORAS.md](docs/fork/PLAN-MEJORAS.md) §F5-bis.1.
- Tests e2e con Playwright contra el stack real (`e2e/`, con su [README](e2e/README.md)), con un workflow propio (`.github/workflows/fork-quality.yml`).
- **Scripts del fork**: [`scripts/fork/`](scripts/fork/README.md) con la puerta de calidad (`check.sh`) y el **sync con el upstream en una orden** (`sync-upstream.sh`). El upstream publica cada 1-2 semanas; esto lo convierte en 20 minutos con todo verificado.
- Plan de mejoras: [docs/fork/PLAN-MEJORAS.md](docs/fork/PLAN-MEJORAS.md) · Línea base: [docs/fork/BASELINE.md](docs/fork/BASELINE.md)

## Relación con el upstream
- **Se sigue al upstream** (decisión D-0, 8-nov-2026): sync periódico desde `upstream/main`.
- **Estado:** sigue a **upstream v1.4.5** (sync del 24-nov-2026, 1068 commits, 0 conflictos). El remoto
  `upstream` es `https://github.com/DuarteSantos8/openGym.git`; el procedimiento es
  `git fetch upstream && git rebase upstream/main` (los commits del fork son **adiciones de ficheros nuevos**,
  así que no chocan).
- Regla del fork: **no se editan archivos del upstream** si se puede evitar. Lo propio va en archivos nuevos (`FORK.md`, `docs/fork/`, `e2e/`, código nuevo), y las funcionalidades útiles se proponen upstream como PR.
  **Límite conocido:** una regla de progresión nueva o un campo de estado nuevo **sí** obligan a tocar ficheros
  del upstream (§F5-bis.3 del plan). Cuando pase, la señal es: márchalo upstream.
- Workflows de GitHub Actions que no aplican al fork: **desactivados desde GitHub**, no borrados ni editados (ver docs/fork/PLAN-MEJORAS.md, H1.1).

## Licencia
- Código: **AGPL-3.0-or-later**, igual que el original (ver `LICENSE`). Los cambios de este fork tienen la misma licencia.
- Medios del catálogo de ejercicios: licencia propia, ver `NOTICE.md` y `catalogue/media/NOTICE.md`.
- **Obligación AGPL §13:** si esta versión modificada se ofrece a otras personas por red, hay que darles acceso al código fuente de esta versión.
  - Estado actual: uso personal en local (`localhost`). No aplica todavía.
  - **Disparador:** el día que la instancia sea accesible por otra persona (Tailscale compartido, dominio público, cualquier usuario que no seas tú), antes de dar acceso se añade un enlace visible al código fuente de este fork (por ejemplo, en Ajustes → Acerca de) o se publica el repo con los cambios.
- `CLA.md` es el acuerdo de contribución del **proyecto original**. Aplica a los PR que se envíen upstream, no a este fork.
