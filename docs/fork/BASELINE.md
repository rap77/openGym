# Línea base del fork (F0)

Fecha: 9-nov-2026 · Commit: `ac3cbecb7` (upstream/main + 2 commits de docs) · Logs: `~/proy/opengym-baseline/`

## Entorno
| | Valor |
|---|---|
| Node / npm | v22.23.4 / 10.9.9 (igual que CI y Dockerfile, vía nvm + `.nvmrc`) |
| Docker / Compose | 29.2.1 / v5.0.2 |
| SO | Debian en WSL2 (Windows) |
| Sync upstream | `0 2`: al día con `upstream/main` |

## Resultados
| Paso | Resultado | Tiempo |
|---|---|---|
| `npm ci` (raíz, api, frontend, mcp) | ✅ 4/4 | — |
| Tests api (`node --test`) | ⚠️ 783/800 pasan · **17 fallan** | 375 s |
| Tests frontend (vitest) | ⚠️ 7780/7832 pasan · **52 fallan** (13 de 651 archivos) | 738 s |
| Tests mcp | ✅ 138/138 | 6 s |
| Chequeos CI (locales, catálogo, coach-assets, api-docs) | ✅ 4/4 | — |
| Build frontend | ✅ | 5 s |
| `bundle-size.mjs` | ✅ **28 586 kB sin comprimir · 5 750 kB gzip · 111 archivos** (`bundle-base.json`) | — |
| Stack Docker (api + web) | ✅ ambos `healthy` | — |
| `/api/health` | ✅ `{"ok":true,"users":0,"writable":true}` HTTP 200 | — |
| Prueba manual en el navegador | ✅ 9-nov: Create profile con passkey → rutina "Push Day" → 1 serie (press banca 10 kg × 8) → aparece en Progreso/historial, con PR detectado. UI en español OK. (El primer intento falló por usar "Sign in" sin perfil creado: error de instrucciones, no de la app) | — |
| Tests con Node 24 (sistema, v24.19.0) | api ✅ · frontend 80 fallan · mcp 9 fallan (ver abajo) | — |

## Diagnóstico de fallos con Node 22 (confirmado)
Re-ejecución en solitario, sin paralelismo:
- **api:** 71/71 pasan (los 9 archivos que fallaron). Los 17 fallos eran **por carga del entorno**.
- **frontend:** 426/428 pasan (los 8 archivos principales). Solo quedan 2 fallos, ambos `Test timed out in 5000ms` en `src/lib/media-sync.test.js` (`localMediaGc`).
- **Conclusión:** la suite completa en paralelo satura WSL (frontend 738 s). **No hay fallos de lógica confirmados.**

**Deuda D-B1: `media-sync.test.js` hace timeout incluso en solitario.**
- Probable test lento en WSL (E/S de archivos).
- Acción: correrlo solo, con `--testTimeout=20000`. Si pasa → anotar como lento por entorno y cerrar. Si falla → reportar upstream.
- Disparador: antes de tocar cualquier cosa de `media-sync` / `lib/pose` (que guardará datos en la serie).

**Deuda D-B2: 5 archivos del frontend que fallaron en paralelo y no se re-ejecutaron** (`card-dismiss`, `coach-api.i18n`, `AdminCoach`, `FocusView`, `Library`).
- Disparador: en el próximo cierre de F0 o antes del primer PR. Correrlos en solitario.

**Para el día a día:** usar `npx vitest run --maxWorkers=2` en WSL (hipótesis: evita la saturación; validar en la primera ejecución).

## Node 24 (v24.19.0) vs Node 22
| Paquete | Node 22 (suite completa) | Node 24 (suite completa) |
|---|---|---|
| api | 17 fallan (entorno) | ✅ 0 fallan |
| frontend | 52 fallan (entorno) | 80 fallan: **`AdminCoach.test.jsx` 55**, `coach-api.i18n.test.js` 15, `Library` 4, `media-sync` 2, otros 4 |
| mcp | ✅ 0 | 9 fallan en `state.test.js` (timeouts) + 1 en e2e |

- La concentración en `AdminCoach` y `coach-api.i18n` (errores `Cannot read properties of undefined (reading 'click' / 'constructor')`) sugiere una **incompatibilidad real con Node 24** en el área del Coach, no solo carga.
- `app-icons.mjs --check` también falló con Node 24.
- **Deuda D-B3: compatibilidad con Node 24.** No se arregla en el fork (D-0 = seguir upstream).
  - Disparador: cuando upstream pase a Node 24, o a más tardar el **30-abr-2027** (fin de soporte de Node 22).
  - Ese día: re-ejecutar en solitario `AdminCoach.test.jsx` y `coach-api.i18n.test.js` con Node 24. Si siguen fallando, abrir un issue upstream con el log.

## Pendientes para cerrar F0
**F0 cerrada el 9-nov-2026.** Lo que queda abierto son deudas con disparador propio:
- D-B1 y D-B2: antes del primer PR o antes de tocar `media-sync`.
- D-B3 (Node 24): cuando upstream migre, o el 30-abr-2027.
- `.nvmrc` (22): se versiona en el fork; candidato a PR upstream junto con el primer PR de la funcionalidad de visión.
