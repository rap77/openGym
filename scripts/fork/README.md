# scripts/fork — los scripts del fork

Ficheros **del fork**, en un directorio que el upstream nunca toca. Por eso cada sync sale sin
conflictos: el upstream no sabe que existen.

## `check.sh` — la puerta de calidad

Lo mismo que corre el CI del upstream, en una sola orden y en local:

```bash
scripts/fork/check.sh                 # todo: checks, tres suites y e2e
scripts/fork/check.sh --no-e2e        # sin la e2e (no hace falta Docker)
scripts/fork/check.sh --install       # npm ci antes de nada
```

Qué corre:

| Paso | Qué es |
|---|---|
| `check-locales` | Los packs de idioma están sincronizados entre sí |
| `check-source-strings --strict` | Toda clave `t('…')` del código existe en algún pack |
| `catalogue/build --check` | Los ficheros generados del catálogo están al día |
| `build-coach-assets --check` | Los assets del Coach están al día |
| `build-api-docs --check` | La documentación de la API está al día |
| `api` | `node --test` (1084 tests) |
| `mcp` | La suite del servidor MCP (153 tests) |
| `frontend` | `vitest run --maxWorkers=4` (10101 tests) |
| `e2e` | Playwright contra el stack aislado (4 escenarios) |

**Por qué `--maxWorkers=4` y no el que toque:** el test de `media-sync` reserva 200 MB + 150 MB de
blobs en memoria. Con 12 workers en paralelo la máquina se queda sin RAM y ese test caduca a los
5 s; es la deuda D-B1/D-B4 del [BASELINE](../BASELINE.md), no un fallo de lógica. Con 4 workers la
suite entera pasa. Se puede cambiar con `FRONTEND_MAX_WORKERS=8 scripts/fork/check.sh`.

**Por qué comprueba la versión de Node:** el repo pide la de `.nvmrc` (22) y con otra el upstream da
fallos falsos (`AdminCoach`, `coach-api.i18n`). El script cambia solo con nvm si puede, y si no,
para y lo dice.

## `sync-upstream.sh` — sincronizar con el upstream

El upstream publica **cada 1-2 semanas** con 300+ ficheros. Esto lo hace en una orden:

```bash
scripts/fork/sync-upstream.sh              # sincroniza, verifica y se para
scripts/fork/sync-upstream.sh --push       # ademas sube el resultado a origin/main
scripts/fork/sync-upstream.sh --no-e2e     # sin la e2e
```

Qué hace, en orden:

1. **Preflight.** Rama `main`, remoto `upstream` presente, sin cambios sin commitear en ficheros ya
   versionados (esos se perderían). Los ficheros **sin versionar** solo avisan: el rebase no los
   toca, y si el upstream trae uno del mismo nombre, el script se para y lo dice.
2. **`git fetch upstream`** y el recuento de cuántos commits trae.
3. **Rama de seguridad** `backup/pre-sync-<fecha>` con el estado anterior.
4. **`git rebase upstream/main`.** Los commits del fork son solo adiciones de ficheros nuevos, así
   que no chockan. Si hubiera un conflicto, el script **aborta el rebase**, deja el repo como
   estaba y te dice qué ficheros chocaron.
5. **`npm ci` solo en los paquetes que cambiaron** (raíz, `api`, `frontend`, `mcp`, `e2e`).
6. **`check.sh`**, la puerta de calidad completa.
7. **No sube nada si algo falla.** Con `--push` usa `--force-with-lease`, que falla si `origin/main`
   se movió por debajo: nunca se pisa trabajo de otra persona.

El rebase (y no el merge) es a propósito: deja `main` lineal encima de `upstream/main`, así que cada
sync futuro rebasa solo los commits nuevos y `git diff upstream/main...main` es exactamente lo tuyo.

**Un conflicto en este rebase es una señal**: significa que un commit del fork ya está tocando un
fichero del upstream. Lo normal es que esa funcionalidad vaya **upstream**, no en el fork.

## `lib.sh` — utilidades compartidas

Colores, logs, el control de la versión de Node y la detección de qué paquetes cambiaron. No se
ejecuta directamente.
