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
| `frontend` | `vitest run` **con los flags exactos del upstream** (10101 tests) |
| `e2e` | Playwright contra el stack aislado (4 escenarios) |

### El frontend corre con los flags del upstream, a propósito

No es capricho: es **el comando que decide un PR**, así que una puerta verde tiene que predecir lo que
va a pasar upstream. El comando del upstream (`.github/workflows/test.yml`) es:

```
npx vitest run --reporter=default --coverage --coverage.provider=v8 --coverage.include='src/**'
```

**Y da un resultado distinto al de otros flags**, porque la suite tiene tests cuyo resultado depende
del agrupamiento de ficheros en workers (ver más abajo). Con `--maxWorkers=4` la suite pasa; con los
flags del upstream, a veces no.

### La puerta distingue "fallo mío" de "fallo del upstream"

Si el frontend falla, el script mira **qué ficheros de test fallaron** y los compara con los que toca
el fork (`git diff upstream/main...main`):

- **Fallo en un fichero mío** → la puerta **falla**. Es mío.
- **Fallo en un fichero que no toco** → la puerta **avisa y sigue**. Es del upstream: un PR mío se
  mediría con esa misma suite, así que hay que reportarlo upstream antes de abrir el PR.

Hoy el fork **no toca ni un fichero de `frontend/`**, así que cualquier fallo del frontend es del
upstream por definición. La puerta lo dice con nombre y apellidos en vez de dejarte adivinar.

### El bug que la puerta encontró (y que ya está reportado)

El primer `check` en CI del fork falló con 4 tests de `src/components/SetVideo.test.jsx`. Diagnóstico:

| Combinación | Resultado |
|---|---|
| `SetVideo.test.jsx` solo | ✅ 10/10 |
| `CoachIntake.test.jsx` solo | ✅ 45/45 |
| `PasswordAuth.test.jsx` solo | ✅ 29/29 |
| `SetVideo` + `CoachIntake` | ❌ **4 fallan** (51 pasan) |
| `SetVideo` + `PasswordAuth` | ❌ **2 fallan** (37 pasan) |

Es un **fallo de aislamiento entre ficheros de test**: los ficheros que sustituyen el módulo del store
con `vi.mock('../store/useStore.js')` se filtran a los ficheros que van después en el mismo worker, y
el `config` que el test pone en el store deja de ser el que la app lee. Como el agrupamiento depende
del número de workers, parece un flake.

Reportado upstream: **https://github.com/DuarteSantos8/openGym/issues/1562**

**Un aviso que costó tiempo:** no corras **dos vitest a la vez** en el mismo repo. Se pelean por
`frontend/coverage/.tmp` y cada uno corrompe al otro:

```
Error: Something removed the coverage directory ".../frontend/coverage/.tmp"
Make sure you are not running multiple Vitests with the same "coverage.reportsDirectory" at the same time.
```

### Por qué comprueba la versión de Node

El repo pide la de `.nvmrc` (22) y con otra el upstream da fallos falsos (`AdminCoach`,
`coach-api.i18n`). El script cambia solo con nvm si puede, y si no, para y lo dice.

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
