# openGym (fork): plan de mejoras

Fecha: 8-nov-2026 · Repo: `~/proy/openGym` (WSL) · Base: v1.4.4 del upstream DuarteSantos8/openGym

> Este plan parte de un análisis estático (estructura, documentación y tamaños de archivo). Nada se ha ejecutado todavía: la Fase 0 sirve para medir la línea base real.
> Cada deuda tiene un **disparador de vencimiento** concreto. Ninguna queda para "cuando haya tiempo".

## Decisión previa (bloquea todo lo demás)

**D-0: ¿qué relación vas a mantener con el upstream?** → ✅ **Decidido 8-nov-2026: A, seguir al upstream.**

| Opción | Implica |
|---|---|
| A. Seguir el upstream (rebase o merge periódico) | Las refactorizaciones grandes (F3, F4) generan conflictos en cada release del original, que publica cada 1–2 semanas. Lo mejor es limitarse a cambios aditivos y proponerlos upstream como PR. |
| B. Divergir (fork independiente) | Hay libertad para refactorizar, pero dejas de recibir fixes y el catálogo nuevo. |

Disparador: decidir antes de empezar F3. Mientras D-0 siga abierta, solo se ejecutan F0, F1 y F2.

---

## Fase 0: Línea base (½ día)

**H0.1 Medir el estado real**
- Comandos: `npm ci` en la raíz, `api/`, `frontend/` y `mcp/`; `npm test` en cada uno; `cd frontend && npm run build`; los checks de CLAUDE.md (`check-locales`, `catalogue/build.mjs --check`, `build-coach-assets --check`, `build-api-docs --check`).
- Aceptación: queda guardado en `docs/fork/BASELINE.md` el número de tests pasados y fallidos por paquete, el tamaño del bundle (`scripts/bundle-size.mjs`) y el tiempo de build. Todo lo que ya fallaba antes de tocar nada queda listado.

**H0.2 Arrancar el stack**
- `cp .env.example .env && docker compose up -d --build`. Registrar con passkey y guardar un entreno.
- Aceptación: el flujo funciona en local y `/api/health` responde OK.

## Fase 1: Adaptar el fork ✅ 9-nov-2026 (revisada para D-0 = seguir upstream)

**Principio:** F1 **no edita archivos del autor** (workflows, compose, README, helm). Cada edición sería un conflicto en cada sync. Se resuelve con configuración de GitHub, archivos locales sin versionar y archivos nuevos.

**H1.1 Workflows: desactivar desde GitHub, sin editar YAML**
| Workflow | En el fork | Acción |
|---|---|---|
| `mirror.yml` | Guarda `github.repository == 'DuarteSantos8/openGym'` → el job se salta solo | Desactivar igual (que no aparezca en Actions) |
| `cla.yml`, `cla-issue.yml` | Pediría el CLA del autor en tus PR | Desactivar |
| `pages.yml` | Intentaría publicar la demo en rap77.github.io | Desactivar |
| `ios.yml` | Builds macOS sin firma, fallan y gastan minutos | Desactivar |
| `docker-publish.yml` | Solo en `release`; publicaría en `ghcr.io/rap77` | Desactivar. **Disparador para reactivarlo:** cuando quieras imágenes propias publicadas |
| `test.yml`, `audit.yml`, `release-check.yml` | Útiles | Mantener |
- Aceptación: en Actions de rap77/openGym solo quedan habilitados Tests, Audit y Release check.
- ✅ 11-nov-2026: desactivados CLA, CLA (issue), Pages, iOS y Publish Docker images. Mirror se deja habilitado: se salta solo por su guarda (corridas #1 y #2 en gris). Tests #1 y #2 en verde (~30 s: la ejecución es corta porque los commits solo tocan docs).

**H1.2 Imágenes: override local, sin tocar `docker-compose.yml`** ✅
- `docker-compose.override.yml` (excluido en `.git/info/exclude`) → `opengym-fork-*:local` con `pull_policy: build`.
- README, helm, kubernetes y nix **no se tocan**. Disparador: desplegar el fork fuera de tu PC.
- Aceptación: `docker compose config | grep image:` muestra solo `opengym-fork-*` ✅ (9-nov).

**H1.3 Identidad y licencia** ✅: `FORK.md` (archivo nuevo) con la relación con upstream, AGPL §13 y su disparador, y el CLA.

**H1.4 Remotos** ✅: `origin` = rap77, `upstream` = DuarteSantos8.

**H1.5 `.npm-cache/` sin versionar:** ✅ 11-nov-2026, añadido a `.git/info/exclude`. Stack reconstruido con `opengym-fork-*:local`: `/api/health` 200, `users: 1`.

**Procedimiento de sync con upstream** (antes de cada bloque de trabajo y con cada release del original):
`git fetch upstream && git merge --ff-only upstream/main || git rebase upstream/main` → `npm ci` en los paquetes cambiados → tests en solitario de lo que toque el fork.

## Fase 2: Calidad sin tocar lógica (2–3 días)

**H2.1 Linter y formateador**
- Biome (un binario, rápido) o ESLint+Prettier. La config va en la raíz, para `api/`, `frontend/` y `mcp/`.
- Primero se aplica solo a los archivos tocados (lint-staged). El formateo de todo el repo va en **un commit `chore` separado**.
- Disparador del formateo global: cuando H2.1 lleve una semana estable en CI (si D-0 = A, nunca en el fork: proponerlo upstream).
- Aceptación: job `lint` en `test.yml` en verde, bloqueante para los archivos modificados.

**H2.2 Chequeo de tipos ligero**
- `// @ts-check` + JSDoc y `tsc --noEmit` con `allowJs` y `checkJs`, empezando por `api/*.js` (módulos pequeños) y `frontend/src/lib/`.
- Aceptación: job `typecheck` en verde para los directorios incluidos. Disparador de ampliación: cada módulo que se toque en F3 entra en el alcance del typecheck en ese mismo PR.

**H2.3 Tests E2E de interfaz**
- Playwright con autenticador WebAuthn virtual: registro, crear rutina, registrar entreno, ver historial y sincronizar entre dos contextos.
- Aceptación: 3–5 escenarios que corren contra `docker compose` en CI, en menos de 5 minutos.

**H2.4 Workspace npm**
- Convertir el `package.json` raíz (hoy solo tiene `js-yaml`) en workspaces `api`, `frontend` y `mcp`, con scripts `test`, `lint` y `typecheck` globales.
- Aceptación: `npm test` en la raíz corre las tres suites.

## Fase 3: Refactorización estructural (solo coordinada con upstream; con D-0 = A no se hace en el fork)

**Disparador para reconsiderarla:** 2 syncs seguidos con conflictos en `sheets.jsx` o `server.js` de más de 1 h cada uno, **o** que el upstream anuncie su propia división. En ese caso se propone upstream.

Requisito: F0 y H2.3 terminados (red de tests E2E disponible).

**H3.1 Partir `frontend/src/sheets.jsx`** (4.147 líneas, ~88 funciones, 70 `useState`)
- Crear `src/sheets/` con un archivo por hoja e `index.js` que reexporte lo mismo (sin cambiar la API pública). Los ~100 tests `sheets.*.test.jsx` no deberían necesitar cambios.
- Por pasos: 1 PR por grupo de hojas (workout, plan, library, weigh-in, settings…).
- Aceptación: tests verdes en cada PR, ningún archivo con más de 600 líneas y bundle igual o menor que la línea base.

**H3.2 Lazy-loading de hojas y vistas**
- `React.lazy` + `Suspense` para las hojas poco usadas (import, backups, coach, admin).
- Aceptación: el bundle inicial baja al menos un 15 % frente a BASELINE (medido con `bundle-size.mjs`).

**H3.3 Partir `api/server.js`** (3.150 líneas)
- Mover a `api/src/` con `routes/` (auth, data, admin, media, push, coach), `session/` y `storage/`. `server.js` queda solo para arrancar.
- Dockerfile: sustituir el `COPY` con 19 archivos listados a mano por `COPY src ./src`. Mantener `dockerfile-copy.test.js`.
- Aceptación: los ~104 tests de la api verdes, `openapi-routes.test.js` verde y la imagen arranca (smoke test del CI).

**H3.4 Estado del frontend**
- Pasar el estado compartido de las hojas a los stores de Zustand o a hooks propios (`useWorkoutSheet`, etc.).
- Disparador (Rule of Three): al tercer `useState` duplicado entre hojas, se extrae un hook en el mismo PR.

## Fase 4: Almacenamiento (más adelante)

**H4.1 Capa de repositorio**
- Interfaz `Storage` (getUser, getState, saveState, …) con la implementación JSON actual detrás. Sin cambio funcional.

**H4.2 Backend SQLite opcional**
- `node:sqlite` (Node 22+) o better-sqlite3, activado con la variable `STORAGE=sqlite`, más un migrador `json → sqlite` idempotente con backup previo.
- Disparador para empezar F4: cualquiera de estas condiciones: más de 20 usuarios por instancia, `state-<user>.json` de más de 5 MB, o la primera corrupción o conflicto de escritura concurrente reportado. Alternativa: que el upstream lo haga (está en su ROADMAP, "Later: database storage"). En ese caso se adopta lo suyo.

## Fase 5: Tu diferenciación (por definir)

¿Qué quieres que tenga tu fork que el original no tenga? Ejemplos: multi-tenant para un gimnasio, panel de entrenador, español como idioma por defecto, integración con tus herramientas. Se define después de F1.

---

## Resumen

| Fase | Esfuerzo | Riesgo | Depende de |
|---|---|---|---|
| F0 Línea base | ½ d | nulo | — |
| F1 Adaptar fork | 1 d | nulo | F0 |
| F2 Calidad | 2–3 d | bajo | F0 |
| F3 Refactorización | 5–8 d | medio | D-0, H2.3 |
| F4 SQLite | 3–5 d | medio-alto | disparador, F3.3 |
| F5 Diferenciación | — | — | F1 |

Orden recomendado: **F0 → F1 → H2.1 → H2.3 → D-0 → el resto**.
 | nulo | F0 |
| F2 Calidad | 2–3 d | bajo | F0 |
| F3 Refactorización | 5–8 d | medio | D-0, H2.3 |
| F4 SQLite | 3–5 d | medio-alto | disparador, F3.3 |
| F5 Diferenciación | — | — | F1 |

Orden recomendado: **F0 → F1 → H2.1 → H2.3 → D-0 → el resto**.
