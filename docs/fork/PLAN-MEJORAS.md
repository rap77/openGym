# openGym (fork): plan de mejoras

Fecha: 24-nov-2026 · Repo: `~/proy/openGym` (WSL) · Base: **v1.4.5** del upstream DuarteSantos8/openGym

> Este plan parte de un análisis estático (estructura, documentación y tamaños de archivo). Nada se ha ejecutado todavía: la Fase 0 sirve para medir la línea base real.
> Cada deuda tiene un **disparador de vencimiento** concreto. Ninguna queda para "cuando haya tiempo".

> **Revisión del 24-nov-2026 (tras el sync a v1.4.5).** F0, F1 y H2.3 están **cerradas y medidas** (ver
> [BASELINE.md](BASELINE.md)). El sync (1068 commits) salió **limpio, con 0 conflictos**, y la suite entera
> del upstream pasa (api 1084/1084, frontend 10101/10101, mcp 153/153, e2e 3/3).
> **La Fase 5 se re-toca:** el 1.4.5 se comió casi todo lo que F5 rayaba construir. Ver **§F5-bis**.

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

## Fase 2: Calidad sin tocar lógica (revisada 11-nov-2026 para D-0 = seguir upstream) — ✅ **cerrada 24-nov-2026**

**Hallazgo (11-nov):** `test.yml` decide qué corre con `dorny/paths-filter` (job `changes`). Un commit que solo toca docs se salta todas las suites, por eso salió verde en ~30 s. El upstream ya tiene CI por áreas, `test-audit.mjs` y `bundle-size` en CI.

**Principio:** como en F1, no se edita `test.yml`, ni los `package.json` del autor, ni se reformatea su código. La calidad propia del fork vive en **archivos nuevos** y en un **workflow nuevo** (`.github/workflows/fork-quality.yml`), que el upstream nunca toca.

**H2.3 Tests E2E con Playwright (se hace PRIMERO, antes de V1.0)**
- Carpeta nueva `e2e/` en la raíz, con `package.json` propio (como `mcp/`). Playwright contra el stack de `docker compose`, con autenticador WebAuthn virtual (CDP `WebAuthn.addVirtualAuthenticator`): sin passkey real.
- Escenarios (automatizan la prueba manual de F0):
  1. Create profile → entra en Inicio.
  2. Crear rutina con 1 ejercicio → empezar → marcar 1 serie → terminar.
  3. El entreno aparece en Progreso y se detecta el PR.
  4. Cerrar sesión → Sign in con la misma passkey virtual → los datos siguen.
- CI: job `e2e` en `fork-quality.yml` (build del stack + Playwright + traza como artefacto si falla).
- Aceptación: los 4 escenarios en verde en < 5 min, en CI y en local (`cd e2e && npx playwright test`).
- **Progreso 22-nov-2026:** base de `e2e/` creada (`compose.e2e.yml` aislado en :8090 con volumen propio, `run.sh`, passkey virtual por CDP, Playwright 1.65.1 + Chromium 159). **Escenario 1 ✅** (crear perfil con passkey): 24,4 s en frío, 2,9 s en caliente (2 ejecuciones verdes). Pendientes: escenarios 2-4 y job `e2e` en `fork-quality.yml`.
- **Progreso 22-nov-2026 (tarde):** **escenarios 2 y 4 ✅** en `02-workout-and-relogin.spec.js` (entreno libre con 1 serie → hoja "Workout complete!" con 1 set → Stats "All 1" → sign out → sign in con la misma passkey → el entreno sigue). Suite: 2 passed en 1,2 min (`18-e2e.log`). Lecciones de los 4 intentos: el "+" del selector no cierra la hoja (Escape); `page.goto` recarga la SPA y la manda a Inicio (navegar con la barra); tras guardar se abre "Workout complete!" y hay que cerrarla ("Nice!"); "Sign out" está en la subpágina "Account, devices and sync". Pendientes: **escenario 3** (PR detectado: requiere escribir un peso en la serie) y job `e2e` en `fork-quality.yml`.
- **Progreso 22-nov-2026 (noche):** **escenario 3 ✅** en `03-personal-record.spec.js` (40 kg en la serie 1 → resumen con PRs 1, "New PR: barbell bench press" y Volume 400). Pasó al primer intento. **Suite completa: 3 passed en 25,4 s** (`19-e2e.log`). Los 4 escenarios de H2.3 están cubiertos. Pendiente para cerrar H2.3: job `e2e` en `.github/workflows/fork-quality.yml`.
- Por qué primero: es la red de seguridad para tocar `workout-model.js` y la serie activa en V1.0.
- **Disparador para proponerlo upstream:** 2 semanas estable en el fork.
- ✅ **CERRADA 24-nov-2026.** Job `e2e` en `.github/workflows/fork-quality.yml` añadido (commit `d772a42e9c`) y en
  verde en CI (1m32s). Los 3 escenarios pasan en local contra el stack de **v1.4.5** (17,7 s, `24-sync-e2e-2.log`),
  con los **25 selectores verificados uno a uno** contra el código nuevo: ninguno roto. Dos apuntes que costaron
  tiempo y conviene no volver a descubrir:
  - **Playwright 1.65.1 pide Chromium rev 1255.** Si falta en `~/.cache/ms-playwright/`, la e2e falla con
    `Executable doesn't exist at .../chromium_headless_shell-1255/...`. Es el navegador, no la app.
    `npx playwright install chromium` lo arregla (el CI ya lo hace).
  - El placeholder del buscador sigue siendo `Search {0} exercises…` **con contador** (ya lo era en 1.4.4), así que
    el regex `/^Search .* exercises/` de `e2e/helpers/app.js` sigue casando.

**H2.1 Linter y formateador: solo sobre código del fork**
- Biome, con `biome.json` (archivo nuevo) y alcance **solo** en código propio: `e2e/**`, `frontend/src/lib/pose/**`, `frontend/src/views/PoseCoach.jsx`.
- No se formatea código del upstream. Disparador para ampliar: que el upstream adopte un linter, y entonces se usa el suyo.
- Aceptación: `npx @biomejs/biome ci` en verde en `fork-quality.yml`. Se hace junto con H2.3 (primer código propio).

**H2.2 Tipos: `// @ts-check` + JSDoc solo en código del fork**
- `tsconfig.fork.json` (archivo nuevo, `allowJs`, `checkJs`, `noEmit`), con `include` = `frontend/src/lib/pose/**`. Job `typecheck` en `fork-quality.yml`.
- Se hace con el primer commit de V1.0.

**H2.4 Workspace npm: descartado**
- Cambiaría el `package.json` y los lockfiles del autor, con conflicto seguro en cada sync. Se sustituye por `scripts/fork/check.sh` (archivo nuevo): las tres suites con `--maxWorkers=2` + biome + e2e.
- Disparador para reconsiderarlo: que el upstream adopte workspaces.

**H2.5 Deudas de BASELINE antes de H2.3**
- D-B1: `media-sync.test.js` con `--testTimeout=20000`. Si pasa, se cierra como lento por entorno.
- D-B2: los 5 archivos sin re-ejecutar, en solitario.

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

## Fase 5: Tu diferenciación — **redefinida el 24-nov-2026 (F5-bis)**

**Lo que se suponía el 8-nov:** "multi-tenant para un gimnasio, panel de entrenador, español como idioma por
defecto, integración con tus herramientas".

**Lo que pasó:** upstream publicó v1.4.5 el 14-nov (1077 commits, 300+ archivos) y **ya trae casi todo eso**:

| Idea de F5 | Estado en upstream |
|---|---|
| Panel de entrenador | ✅ `TRAINERS=on` (el issue #119 "Personal trainer role" está **cerrado**) |
| Biblioteca de rutinas | ✅ `LIBRARY=on` + `routines/` con esquema JSON, validador en CI y página de envío |
| Importar/exportar rutinas | ✅ QR, enlaces `opengym.ch/r#…`, plan file y "imports donde eliges cada ejercicio" (#931, #849) |
| "Genera mis rutinas" | ✅ el Coach ya **hace** cosas: "3 full-body routines, only bodyweight and a pull-up bar" |
| Formatos de rutina | ✅ circuitos, AMRAP, EMOM, Tabata, run/walk con player a pantalla completa |
| Progresión fina | ✅ tempo por serie (#572), cluster sets, drop-sets, bandas, carries, color tags |
| Español por defecto | ⚠️ sigue siendo una opción, no el valor por defecto |

Y lo que viene:
- **v1.4.6 (diciembre)**: **carpetas de rutinas, archivo, pestaña Routines, color por rutina** (#1207, #1212,
  #1218, #1219).
- **Post-1.4.6 (ROADMAP)**: "el resto del motor de progresión" → **wave/percentage 5-3-1 (#70, #153), rangos de
  repes y AMRAP (#154), generador de warm-up (#156), auto-regulación por RPE (#120)**, supersets editables, fases de
  sesión (#57), coeficientes semanales (#771), "routine variants" (#1022), exercise goals.

> **Conclusión:** construir "personalizar mis rutinas" en paralelo es **reconstruir el ROADMAP del autor**, que
> publica cada 1-2 semanas. Eso no es diferenciación, es una carrera con pérdida.

### F5-bis.1 · Biblioteca propia de rutinas — **la vía barata, sin tocar código** ✅ disponible ya

El upstream abrió la biblioteca como una **interfaz de índices**: un JSON en una dirección https, configurable
**por instancia**, que la app lee directamente (nunca el servidor).

- **Ajuste:** Ajustes (admin) → AI Coach → Advanced → *Routines library*
  (`frontend/src/views/AdminCoach.jsx:385`, parcheado en `api/coach/routes.js:310`, entregado en
  `api/coach/config.js:340`).
- **Clave de config:** `config.coach.routinesUrl`. Vacío = el índice de opengym.ch; `off` = solo los planes
  integrados; una URL https = **la tuya**.
- **Lector en la app:** `frontend/src/lib/routine-library.js:15-19`. Cachea 24 h en `localStorage`
  (`og_routines_index_v1`) y **sigue funcionando si el índice falta o está roto**.
- **Formato:** `docs/ROUTINES_LIBRARY.md` (`"format": "opengym-routines"`, `"version": 1`).
- **Quién lo consume:** el Coach busca entradas que encajen con la pregunta y ofrece una tarjeta
  "Add to my plan"; al importar, las rutinas se añaden junto a las tuyas y el horario solo si lo marcas.

**Lo que esto permite, sin tocar un solo fichero del upstream:**
1. Escribir tus rutinas en JSON con el esquema de `routines/<source>/<slug>.json`.
2. Publicar el **índice** (`{format, version, updated, routines[]}`) en cualquier https: un `raw.githubusercontent.com`
   del propio fork, un jsDelivr, o tu propia instancia con TLS.
3. Pegar esa URL en el ajuste del admin.
4. El Coach te sugiere tus rutinas y las importas con un toque. Sin conflictos de sync, sin commits al upstream.

**Trampa comprobada:** el validador de CI (`node scripts/routines/validate.mjs`) lee
`routines/<source>/*.json` y **valida cada `.json` como si fuera una rutina**. Un `index.json` dentro de
`routines/` rompería el CI. **El índice propio del fork debe vivir fuera de `routines/`** (p. ej.
`fork-routines/index.json`).

### F5-bis.2 · Supervisión por visión — **el hueco que queda de verdad** (sigue en diseño)

El upstream **no** tiene visión por cámara, pero **ya hay un issue abierto que va en esa dirección**:

- **Issue #920 (ABIERTO, 7-nov, propuesto por un usuario, no por el autor)**: contar saltos con la **cámara del
  iPhone y detección de pose on-device** (Vision body pose request de Apple), más intervals automáticos
  hands-free.

Lo que el upstream **no** tiene: rama de visión, nada de pose en el ROADMAP, ni MediaPipe. Y su enfoque, si
llega, sería **nativo iOS**; el diseño de este fork usa **MediaPipe en web/WASM**, que además cubre Android y
escritorio con el mismo código. Ese ángulo cross-platform es la diferencia defendible.

**Disparador (del propio §12 del DISENO-VISION.md, ya comprobado):** antes de empezar V1.0, revisar el issue
tracker y las ramas del upstream. **Hecho el 24-nov: issue #920 abierto, ninguna rama de visión.** La decisión
12.3 (abrir issue/discusión upstream y, si se acepta, PR por hitos) sigue en pie y ahora tiene un dato
concreto que aportar.

### F5-bis.3 · Límite duro de la regla "aditivo-only" ⚠️

La regla del fork ("no se editan archivos del upstream") **funcionó** (sync de 1068 commits con **0 conflictos**)
pero tiene un límite que el plan no cuantificaba:

- **Una rutina nueva, una pantalla nueva, un campo nuevo**: se puede entero en ficheros nuevos. ✅
- **Un tipo nuevo de regla de progresión**: **no**. No hay registro de objetos; la regla es un *string tag*
  resuelto dentro de `nextPrescription` (`frontend/src/lib/progression.js:451-762`). Toca
  `progression.js` (5 listas + la rama), `frontend/src/sheets.jsx` (el *special-casing* del formulario),
  `api/coach/core/validate.js`, `api/coach/core/payload.js`, `api/coach/prompts/common.md`, **los 25 packs de
  i18n** y el test. Y `api/sync-stamps.js` es una **copia manual** del frontend con test de paridad en CI.
- **Un campo persistido nuevo**: escalar → solo `DEF` en `useStore.js`. Pero si es lista con ids o mapa por
  clave → hay que tocar `frontend/src/lib/sync-merge.js` **y** `api/sync-stamps.js` a la vez.

**Coste de sync permanente:** cualquier personalización que toque el motor de progresión o el formato de estado
obliga a mantener cambios en ficheros del upstream para siempre. Eso es un coste, no un Blocking: se acepta,
se documenta y se prefiere **proponerlo upstream** antes de mantenerlo en el fork.

### F5-bis.4 · El coste de i18n subió

De **20 a 25 packs**. Cada string nuevo del fork son 25 traducciones, y `check-locales.mjs` falla el CI si
falta una. La biblioteca de rutinas de F5-bis.1 esquiva esto: el campo `language` del esquema es por rutina.

### F5-bis.5 · Lo que NO es diferenciación (para no perder tiempo)

- Multi-tenant / panel de entrenador → ya está (`TRAINERS=on`).
- Biblioteca de rutinas → ya está (`LIBRARY=on`) y además la del fork es gratis (§F5-bis.1).
- QR / enlaces / import con selección → ya está.
- Coach que genera rutinas → ya está.
- Progresión 5-3-1, rangos de repes, auto-regulación por RPE → está en el ROADMAP del autor.
- Español por defecto → es un ajuste, no una funcionalidad; pero ojo: **25 locales × el `check-locales`** lo hace
  caro.

---

## Sync a upstream v1.4.5 — ✅ **hecho el 24-nov-2026**

El upstream publicó v1.4.5 el 14-nov. El fork se había quedado **1068 commits** atrás (12 delante).

**Procedimiento ejecutado** (el de H1.4, con el remoto `upstream` que faltaba en el clon):

```bash
git remote add upstream https://github.com/DuarteSantos8/openGym.git   # H1.4 decía ✅ pero no estaba
git fetch upstream --filter=blob:none
git branch backup/pre-sync-1.4.5 main                                  # red de seguridad
git rebase upstream/main                                               # 12 commits re-aplicados, 0 conflictos
```

**Por qué rebase y no merge:** los 12 commits del fork son **solo adición de ficheros nuevos**
(`FORK.md`, `docs/fork/`, `e2e/`, `.nvmrc`, `fork-quality.yml`), así que no pueden chocar con el upstream.
El rebase deja `main` lineal sobre `upstream/main` y hace que **cada sync futuro sea un rebase de los commits
nuevos, no un merge**. El push al remoto necesita `--force-with-lease` (ver §F1-H1.4).

**Verificación tras el sync** (todo en verde, detalle en [BASELINE.md](BASELINE.md)):

| | Resultado |
|---|---|
| `git merge-tree main upstream/main` (previo) | 0 conflictos |
| Tests api | 1084/1084 |
| Tests frontend (`--maxWorkers=4`) | 10101/10101 |
| Tests mcp | 153/153 |
| Chequeos CI | 5/5 |
| E2E Playwright | 3/3 |
| Workflows del fork en GitHub | ✅ coinciden con H1.1 (Tests, Audit, Release check, Mirror, Fork quality) |

**Config local que se había perdido en el clon y se reconstruyó** (H1.2 y H1.5):

- `.git/info/exclude` → `.npm-cache/` y `docker-compose.override.yml`.
- `docker-compose.override.yml` → imágenes `opengym-fork-*:local` con `pull_policy: build`.
  Comprobado: `docker compose config | grep image:` **solo** devuelve `opengym-fork-*` (0 imágenes del upstream).
- `.env` → copiado de `.env.example` (RP_ID=localhost, ORIGIN=http://localhost:8080, WEB_PORT=8080).

**Lo que este sync dejó obsoleto en el plan:** la Fase 5 (ver §F5-bis), el objetivo de bundle de H3.2
(la línea base pasó de 28 586 kB a **42 702 kB**) y el número de locales (de 20 a **25**, así que el coste de
i18n de cada string nuevo del fork sube).

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

| Estado | |
|---|---|
| F0 Línea base | ✅ |
| F1 Adaptar fork | ✅ |
| F2 Calidad (H2.3 e2e) | ✅ |
| Sync a v1.4.5 | ✅ 24-nov-2026 |
| H2.1 Biome · H2.2 `@ts-check` | ⏳ pendientes (van con el primer código propio) |
| F5-bis.1 Biblioteca propia de rutinas | ⏳ **la vía barata, sin tocar el upstream** |
| F5-bis.2 Visión por cámara | ⏳ en diseño (DISENO-VISION.md) |
| F3 Refactorización | ⛔ no en el fork con D-0 = A |

**Orden recomendado (actualizado 24-nov-2026):** F0 ✅ → F1 ✅ → F2 ✅ → **sync v1.4.5 ✅** → **F5-bis.1
(biblioteca propia, ½ día y cero conflictos)** → H2.1 + H2.2 (antes de escribir `lib/pose/`) → V1.0 visión
(con la discusión upstream ya abierta, §F5-bis.2) → el resto.

**Antes de cada bloque de trabajo, y con cada release del original:**
`git fetch upstream && git rebase upstream/main` → `npm ci` en los paquetes cambiados → tests en solitario de lo
que toque el fork. Si el rebase choca, `git rebase --abort` y avisar: significa que un commit del fork ya está
tocando un fichero del upstream, y eso es señal de que la funcionalidad debe ir **upstream**.
