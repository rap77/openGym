# Línea base del fork (F0)

Fecha: 24-nov-2026 · Commit: `d772a42e9c` (upstream `v1.4.5` + 12 commits del fork) · Logs: `~/proy/opengym-baseline/`

> Última medición: **24-nov-2026**, tras el sync a upstream v1.4.5 (1068 commits de atraso).
> La medición anterior (9-nov, sobre v1.4.4) queda al final como histórico.

## Entorno

| | Valor |
|---|---|
| Node / npm | v22.22.0 / 10.9.4 (el de `.nvmrc`; CI y los Dockerfile usan 22) |
| Docker / Compose | 29.9.3 / v5.7.0 |
| SO | Debian en WSL2 (Windows) |
| CPU / RAM | 12 CPU · 23 GiB |
| Upstream | v1.4.5, sincronizado el 24-nov-2026 (`git merge-tree` → 0 conflictos) |

**El nodo del sistema es v24.13.0.** Con 24 el upstream da ~80 fallos falsos (D-B3). Todo lo de abajo se midió
con **v22.22.0**, el de `.nvmrc`.

## Resultados

| Paso | Resultado | Tiempo |
|---|---|---|
| `npm ci` (raíz, api, frontend, mcp, e2e) | ✅ 5/5 | — |
| Tests api (`node --test`) | ✅ **1084/1084** | 105 s |
| Tests frontend (vitest, `--maxWorkers=4`) | ✅ **10101/10101** | 317 s |
| Tests frontend (vitest, paralelismo por defecto) | ⚠️ 10100/10101 · 1 timeout | 285 s |
| Tests mcp | ✅ **153/153** | 7 s |
| Chequeos CI (locales, source-strings, catálogo, coach-assets, api-docs) | ✅ 5/5 | — |
| Build frontend | ✅ | 3,7 s |
| `frontend/scripts/bundle-size.mjs` | ⚠️ **42 702 kB sin comprimir · 9 558 kB gzip · 166 archivos** | — |
| E2E Playwright (3 escenarios) | ✅ **3/3** | 17,7 s |
| Sync a upstream v1.4.5 | ✅ limpio, 0 conflictos, 12 commits del fork re-aplicados | — |

## Qué cambió respecto a v1.4.4 (línea base del 9-nov)

| | v1.4.4 (9-nov) | v1.4.5 (24-nov) | Δ |
|---|---|---|---|
| Tests api | 783/800 (17 fallos de entorno) | **1084/1084** | +301 tests, 0 fallos |
| Tests frontend | 7780/7832 (52 fallos de entorno) | **10101/10101** | +2319 tests, 0 fallos |
| Tests mcp | 138/138 | **153/153** | +15 (el servidor MCP sobre HTTP es nuevo) |
| Ficheros de test (frontend) | 651 | **898** | +247 |
| Locales | 20 | **25** | +5 idiomas → **el coste de i18n del fork subió de 20 a 25 packs por string** |
| Bundle raw | 28 586 kB | **42 702 kB** | **+49 %** |
| Bundle gzip | 5 750 kB | **9 558 kB** | **+66 %** |
| Ficheros del bundle | 111 | **166** | +55 |
| New top-level en el upstream | — | `routines/`, `cloudflare/`, `fastlane/`, `.coderabbit.yaml` | — |

**El bundle casi se duplica.** El objetivo de H3.2 ("−15 % frente a la línea base") tiene que volver a
medirse contra 42 702 kB, no contra 28 586 kB.

## Deuda D-B1: `media-sync.test.js` (sigue viva, con otro matiz)

Con el paralelismo por defecto (12 workers) **falla 1 test**:

```
src/lib/media-sync.test.js > localMediaGc >
  signed in, evicts synced main files over the cap — never a pending one or a poster the state shows
Error: Test timed out in 5000ms.
```

**No es una regresión del sync.** Tres pruebas:

1. `git diff v1.4.4 main -- frontend/src/lib/media-sync.test.js` está **vacío**: el fichero de test no cambió.
2. En solitario pasa **31/31 en 2,79 s** (`npx vitest run src/lib/media-sync.test.js --testTimeout=20000`).
3. El test reserva **200 MB + 150 MB** de blobs (`new Uint8Array(200 * MB)`), que es exactamente la
   causa de D-B1/D-B4: con 12 workers en paralelo la memoria se agota y el test no llega al final en 5 s.

**Acción:** correr el frontend con `--maxWorkers=4` (o menos). Con eso la suite entera pasa en verde
(10101/10101, 317 s). El CI del upstream no sufre esto porque sus runners tienen la memoria justa para
el paralelismo que él pide.

> D-B4 (memoria de WSL) queda **superada**: la máquina actual tiene 23 GiB y 12 CPU, no los 7,6 GiB de
> noviembre. El cuello de botella ya no es WSL, es el propio test con 350 MB de blobs en memoria.

## D-B3: Node 24 (sin cambios)

Con v24.13.0 el upstream falla en `AdminCoach` y `coach-api.i18n`. **No se arregla en el fork** (D-0 = seguir
upstream). Disparador: cuando upstream pase a Node 24, o a más tardar el **30-abr-2027** (fin de soporte de
Node 22).

## Deuda D-B2 (cerrada de hecho)

Los 5 ficheros que en la línea base del 9-nov no se habían re-ejecutado (`card-dismiss`, `coach-api.i18n`,
`AdminCoach`, `FocusView`, `Library`) ahora **pasan** dentro de la suite completa: 10101/10101.

## Para el día a día

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.0/bin:$PATH"   # el Node de .nvmrc
cd frontend && npx vitest run --maxWorkers=4                  # verde con memoria
cd e2e && npx playwright install chromium                     # si Playwright cambia de revisión
e2e/run.sh --down                                            # stack aislado en :8090 + 3 escenarios
```

**Playwright 1.65.1 pide Chromium rev 1255.** Si `~/.cache/ms-playwright/` no lo tiene, la e2e falla con
`Executable doesn't exist at .../chromium_headless_shell-1255/...` — **no es un fallo de la app**, es el
navegador que falta. El CI lo instala con `npx playwright install --with-deps chromium`.

---

# Línea base del fork (F0) — histórico, 9-nov-2026

> Commit `ac3cbecb7` (upstream/main + 2 commits de docs). Logs: `~/proy/opengym-baseline/`.

| | Valor |
|---|---|
| Node / npm | v22.23.4 / 10.9.9 |
| Docker / Compose | 29.2.1 / v5.0.2 |
| SO | Debian en WSL2 (Windows) |
| Sync upstream | `0 2`: al día con `upstream/main` |

| Paso | Resultado | Tiempo |
|---|---|---|
| `npm ci` (raíz, api, frontend, mcp) | ✅ 4/4 | — |
| Tests api (`node --test`) | ⚠️ 783/800 pasan · **17 fallan** | 375 s |
| Tests frontend (vitest) | ⚠️ 7780/7832 pasan · **52 fallan** (13 de 651 archivos) | 738 s |
| Tests mcp | ✅ 138/138 | 6 s |
| Chequeos CI | ✅ 4/4 | — |
| Build frontend | ✅ | 5 s |
| `bundle-size.mjs` | ✅ 28 586 kB · 5 750 kB gzip · 111 archivos | — |
| Stack Docker (api + web) | ✅ ambos `healthy` | — |
| `/api/health` | ✅ `{"ok":true,"users":0,"writable":true}` HTTP 200 | — |

**Diagnóstico de los fallos (9-nov):** los 17 de api y los 52 del frontend eran **por carga del entorno**
(WSL saturado), no de lógica: en solitario pasaban. Con Node 24 fallaban 80 del frontend y 9 del mcp
(D-B3). D-B4 (memoria de WSL) se cerró el 21-nov con `.wslconfig` a 10 GB.

`F0` quedó cerrada el 9-nov-2026.
