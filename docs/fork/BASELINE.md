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
### Resultado de D-B1 y D-B2 (21-nov-2026, Node 22, en solitario)
- **D-B1 `media-sync.test.js`:** 29/31. Los mismos 2 tests de `localMediaGc` hacen timeout **incluso con 20 s**. El archivo tardó **768 s**. Estos tests crean blobs de **200-400 MB** en memoria (`new Uint8Array(400 * MB)`, l. 394).
- **D-B2:** 122/132. `AdminCoach`, `FocusView` y `card-dismiss` pasan. Fallan por **timeout de 5 s** (no por aserción) 9 casos de `coach-api.i18n.test.js` (cargan packs de idioma de 600 kB a 1,6 MB) y 1 de `Library.test.jsx` (pl).
- **Lectura:** los 12 fallos son **timeouts**, ninguno de aserción, y todos en tests que mueven mucha memoria o archivos grandes. La causa probable son los **recursos de WSL** (RAM o CPU asignadas), no el código.
- **Deuda D-B4 (sustituye a D-B1 y D-B2): recursos de WSL.**
  - **Medición 21-nov-2026** (`11-vmstat.log`, cada 5 s durante `media-sync.test.js`): WSL tiene 7,6 GiB de RAM y 8 CPU (Windows: 15,8 GB). Durante el test, la **memoria libre cae a ~77 MB**, entra swap-out (`so` hasta 309), la cola de ejecución llega a 41 y la CPU de sistema (`sy`) a 56 % (paginación/asignación). `wa` ≤ 4 %: no es disco. **Cuello de botella = memoria**: el test de 400 MB acaba ocupando varias copias en RAM.
  - Resultado: 30/31 (falla solo `a guest never loses a referenced file to the cap`, l. 392). Duró **87 s**, frente a 768 s la vez anterior (que probablemente competía con otra carga).
  - `.wslconfig` actual: solo `networkingMode=mirrored`, sin límite de memoria → WSL usa el 50 % por defecto.
  - Acción: `memory=10GB`, `swap=4GB` en `.wslconfig`, conservando `networkingMode=mirrored`. Deja ~5,8 GB a Windows. Después: `wsl --shutdown` y repetir los 3 archivos.
  - ✅ **CERRADA 21-nov-2026: causa = memoria de WSL, no el código.** Con `.wslconfig` en 10 GB (9,7 GiB visibles):
    - `media-sync`, `coach-api.i18n` y `Library`: **86/86 pasan en 22 s** (antes 768 s con fallos). `media-sync` sola: 2,1 s.
    - `12-vmstat.log`: memoria libre mínima **6,2 GB** (antes 77 MB), **swap-out 0** (antes 309), `sy` máx 6 % (antes 56 %), cola máx 5 (antes 41).
    - Configuración aplicada: `C:\\Users\\rpadron\\.wslconfig` (`networkingMode=mirrored`, `memory=10GB`, `swap=4GB`); copia previa en `.wslconfig.bak`.
    - **Requisito del entorno de desarrollo del fork:** WSL con ≥ 10 GB. Si se reinstala WSL o se cambia de PC, esta es la primera comprobación (`free -h`).
    - Pendiente menor: repetir la suite completa del frontend con 10 GB para tener la cifra limpia. **Disparador:** la primera vez que se corra la suite completa en H2.3.
  - Acción: medir con `free -h && nproc` dentro de WSL. Si la RAM es < 8 GB, subirla en `C:\\Users\\rpadron\\.wslconfig` (`[wsl2]` `memory=12GB` `processors=6`), `wsl --shutdown` y repetir los 3 archivos.
  - Si pasan → D-B4 cerrada como entorno.
  - Si siguen fallando con más recursos → issue upstream con los logs `09-db1.log` y `10-db2.log`.
  - **Disparador:** antes de H2.3 (la e2e con Playwright levanta un navegador y el stack, y competirá por la misma RAM).

**F0 cerrada el 9-nov-2026.** Lo que queda abierto son deudas con disparador propio:
- D-B1 y D-B2: antes del primer PR o antes de tocar `media-sync`.
- D-B3 (Node 24): cuando upstream migre, o el 30-abr-2027.
- `.nvmrc` (22): se versiona en el fork; candidato a PR upstream junto con el primer PR de la funcionalidad de visión.
