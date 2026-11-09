# Diseño: supervisión de ejercicios por visión por computadora (fork openGym)

Estado: borrador v0.1 · 8-nov-2026 · Autor: Rafael Padrón
Relacionado: [PLAN-MEJORAS.md](PLAN-MEJORAS.md) (F5) · Programa: vault `fitness-knowledge/06-programas/` · Investigación: vault `fitness-knowledge/04-tecnologia/computer-vision-pose-estimation.md`

## 1. Objetivo

Que la app **lleve el control** de la sesión en casa, sin papel:
1. Contar repeticiones y cronometrar isométricos de forma automática.
2. Medir el tempo (objetivo: 3 s al bajar) y detectar errores de técnica, con aviso por voz.
3. Hacer la **prueba de nivel** sola y proponer el nivel de partida de cada patrón.
4. Guardar en cada serie lo que midió, para la progresión y el coach.

**Fuera de alcance v1:** diagnóstico clínico, ejercicios con carga en el gimnasio, varias personas en cámara, ejercicios en el suelo vistos desde arriba.

## 2. Principios

- **Todo en el dispositivo.** El video nunca sale del equipo y solo se guardan números (reps, tiempos, puntuación). Es coherente con openGym (sin telemetría).
- **Una sola interfaz de pose y varias fuentes.** La lógica de ejercicios no sabe si los puntos vienen de una webcam, del móvil o del Kinect (patrón *adapter*).
- **Reglas como datos.** Umbrales por ejercicio en JSON, versionados y con tests; no hay lógica escondida en componentes.
- **Opcional.** Es un módulo más (Settings → Modules); apagado, no se carga nada (lazy import).
- **Sin ajuste invisible.** Cada umbral se puede calibrar por usuario y la calibración queda guardada.

## 3. Fuentes de pose

| Fuente | Puntos | Ventaja | Limitación | Fase |
|---|---|---|---|---|
| **A. Cámara RGB (webcam o móvil) + MediaPipe Pose Landmarker** (`@mediapipe/tasks-vision`, WASM/WebGL) | 33, en 2D y 3D aproximado | Funciona en el navegador y en las apps Capacitor sin instalar nada | Sensible a la luz y a la ropa; la profundidad es estimada | v1 |
| **B. Kinect v2 (Xbox One) con bridge local** | 25 articulaciones en 3D real (metros) + profundidad + infrarrojo | Profundidad real: ángulos más precisos, funciona con poca luz, el suelo es visible | Necesita el adaptador USB 3.0 para PC y Windows con Kinect SDK 2.0, o libfreenect2 en Linux | v2 |
| **C. Kinect v1 (Xbox 360)** | 20 articulaciones, menor resolución | Igual que B | SDK 1.8 antiguo y peor tracking | Solo si es el único que tienes |

### 3.1 Cómo se integra el Kinect
El navegador no puede leer la profundidad del Kinect. Por eso se usa un **bridge local**:

```
Kinect v2 ──USB3──► kinect-bridge (Windows, C#/.NET con Kinect SDK 2.0)
                     └─ WebSocket ws://localhost:8765  {t, joints:[{name,x,y,z,conf}]}
                                     │
openGym (navegador en el mismo PC) ──┘  PoseSource "kinect"
```

- `kinect-bridge` va en `contrib/kinect-bridge/` como paquete aparte, igual que `mcp/`. **No entra** en la imagen Docker.
- El bridge **convierte** las 25 articulaciones del Kinect a los nombres del modelo común (§4.1). Los puntos que el Kinect no tiene (ojos, orejas, dedos) quedan `null`.
- Modo híbrido opcional: el Kinect también funciona como webcam (RGB), así que se puede usar MediaPipe sobre su imagen y comparar las dos fuentes durante la calibración.
- Solo escucha en `127.0.0.1`, con un token de emparejamiento generado al arrancar (mismo patrón que `mcp/scripts/pair.mjs`).

**Disparador para empezar la v2:** la v1 terminada **y** al menos uno de estos: (a) más del 10 % de falsos conteos en las pruebas de aceptación de la v1 por culpa de la profundidad, (b) querer supervisar ejercicios en el suelo (plancha o puente vistos de frente), o (c) problemas de luz en el sitio donde entrenas.

## 4. Arquitectura

```
frontend/src/lib/pose/           ← puro, sin React, testeable
  source.js        interfaz PoseSource { start(), stop(), onFrame(cb) }
  sources/mediapipe.js           fuente A
  sources/kinect-ws.js           fuente B (cliente WebSocket)
  skeleton.js      modelo común + normalización (escala por largo del torso)
  angles.js        ángulo entre 3 puntos, inclinación vs vertical, alineación de 3 puntos
  smoothing.js     filtro One-Euro por punto (quita temblor sin agregar retardo)
  rules/           <exerciseId>.json → umbrales y fases
  engine.js        máquina de estados por ejercicio → eventos
  calibrate.js     ajusta los umbrales al rango de cada persona
  level-test.js    secuencia de la prueba de nivel → nivel propuesto por patrón
frontend/src/views/PoseCoach.jsx   overlay de cámara + esqueleto + contador + voz
frontend/src/lib/pose/*.test.js    tests con grabaciones de puntos (sin cámara)
```

### 4.1 Modelo común de esqueleto
`{ t: ms, source: 'mediapipe'|'kinect', joints: { nose, shoulderL, shoulderR, elbowL, elbowR, wristL, wristR, hipL, hipR, kneeL, kneeR, ankleL, ankleR, heelL, heelR, toeL, toeR, spineMid?, neck? }, each: {x,y,z,conf} }`
- Coordenadas normalizadas por el **largo del torso** (hombro a cadera), para que los umbrales sirvan en cualquier persona y a cualquier distancia.
- Un punto con `conf < 0.5` cuenta como ausente. Si falta un punto que la regla necesita, el motor no cuenta y avisa "no te veo bien".

### 4.2 Motor (máquina de estados)
Ejemplo de sentadilla a silla:
```
ARRIBA (rodilla > 160°) ──baja──► BAJANDO ──rodilla < umbral_abajo──► ABAJO ──sube──► SUBIENDO ──> 160°──► ARRIBA (+1 rep)
```
- **Histéresis:** entrar en ABAJO exige superar el umbral en 10° y mantenerlo 150 ms. Así se evitan conteos dobles por temblor.
- **Tempo:** se mide el tiempo de BAJANDO (excéntrica) y el de SUBIENDO.
- **Errores:** se comprueban en cada frame dentro de la fase; cada error tiene un mínimo de frames y un tiempo de enfriamiento de la voz (≥ 4 s entre avisos).
- **Eventos emitidos:** `rep{n, eccMs, conMs, depth, errors[]}`, `hold{ms, validMs}`, `formWarning{code}`, `lost`, `found`.
- **Isométricos:** el cronómetro avanza **solo mientras la postura es válida** (`validMs`). Si se pierde la postura durante más de 2 s, la serie termina.

### 4.3 Formato de regla (ejemplo `rules/chair-squat.json`)
```json
{
  "id": "chair-squat", "version": 1, "kind": "reps", "view": "side",
  "primary": { "angle": ["hip", "knee", "ankle"], "top": 160, "bottom": 100, "hysteresis": 10 },
  "tempo":   { "eccentricMinMs": 2500 },
  "errors": [
    { "code": "too_fast",    "when": "eccMs < 2000",              "say": "Más lento al bajar" },
    { "code": "shallow",     "when": "minKnee > 115",             "say": "Baja un poco más" },
    { "code": "torso_lean",  "when": "torsoFromVertical > 45",    "say": "Pecho arriba" },
    { "code": "knee_valgus", "when": "kneeInsideAnkle", "view": "front", "say": "Rodillas hacia fuera" }
  ]
}
```
El lado (izquierdo o derecho) se elige automáticamente: el de mayor confianza media.

## 5. Ejercicios v1 (todos en casa, cámara de lado)

| Ejercicio | Tipo | Ángulo principal | Errores detectados |
|---|---|---|---|
| Sentarse y levantarse / sentadilla a silla / sentadilla libre | reps | cadera-rodilla-tobillo | tempo, profundidad, inclinación del tronco |
| Flexión (pared → completa) | reps | hombro-codo-muñeca | cadera caída o alta (alineación hombro-cadera-tobillo ±10°), rango incompleto |
| Puente de glúteo | reps | hombro-cadera-rodilla | extensión incompleta (< 165°), sin pausa arriba |
| Split squat | reps (por lado) | rodilla delantera | rodilla trasera no baja, tronco inclinado |
| Wall sit | hold | rodilla 80–110° | postura fuera de rango → pausa el cronómetro |
| Plancha (encimera, rodillas, completa) | hold | alineación hombro-cadera-tobillo | cadera caída o alta |
| Equilibrio en un pie | hold | tobillo libre por encima del suelo | apoyo detectado → para el cronómetro |
| Sit-and-reach en silla | medida | distancia muñeca–punta del pie / largo del torso | — |

**Prueba de nivel en la app (`level-test.js`):** sigue el mismo orden que la tabla del programa. Por ejemplo, la sentadilla en 30 s se cuenta sola. El resultado propone el nivel de cada patrón y la fase de entrada con la misma regla del programa (número de patrones en nivel ≥ 3). El usuario confirma y la app crea las rutinas.

## 6. Cambios en el modelo de datos

- Serie (`frontend/src/lib/workout-model.js`), campo opcional nuevo, escrito solo si se usó la cámara:
  `form: { v: 1, source, score: 0-100, reps: [{eccMs, conMs, depth}], errors: {code: count}, validMs? }`
  Las series antiguas no cambian. Los lectores actuales (volumen, récords, progresión) lo ignoran, igual que `type`/`drops`.
- Catálogo (`catalogue/exercises/<id>.json`): `"pose": "chair-squat"` enlaza el ejercicio con su regla.
- Sincronización: `form` viaja con la serie (merge campo a campo). Hay que confirmarlo en `api/test/payload-bounds.test.js`: límite de tamaño de `form.reps` ≤ 50.

## 7. Interfaz

- En la serie activa, un botón **📷 Supervisar** (solo si el ejercicio tiene `pose`).
- La pantalla de cámara muestra: guía de colocación ("ponte de lado a 2–3 m, cuerpo entero"), esqueleto encima de la imagen, contador grande, barra de tempo y semáforo de forma.
- Voz: Web Speech API (`speechSynthesis`), en el idioma de la app, con avisos cortos y un enfriamiento entre ellos.
- Al terminar: la serie se rellena con reps o tiempo y `form`. **El usuario puede corregirla siempre** antes de guardar.
- Sin red: funciona. Los modelos de MediaPipe (≈ 6–9 MB, *lite/full*) se sirven desde el propio nginx de openGym, sin CDN, y el service worker los cachea.

## 8. Rendimiento y privacidad

- Objetivo: ≥ 20 fps de pose y < 150 ms de latencia del aviso en un portátil medio y en un Android de gama media (modelo *lite* en el móvil).
- No se graba video. Un "modo depuración" opcional guarda **solo los puntos** (JSON) para crear fixtures de tests.
- La cámara se apaga al salir de la pantalla y cuando la app pasa a segundo plano.

## 9. Pruebas y aceptación

| Nivel | Qué | Criterio |
|---|---|---|
| Unitario | `angles`, `smoothing`, `engine` con fixtures de puntos grabados | 100 % de las reglas v1 con fixture correcto, fixture con error y fixture con "persona perdida" |
| Conteo | 3 grabaciones por ejercicio (lento, rápido, con errores) | Error de conteo ≤ 1 rep por cada 20, sin conteos dobles |
| Isométricos | Wall sit y plancha con pérdidas de postura simuladas | `validMs` dentro de ±0,5 s del tiempo real |
| Forma | Errores inducidos a propósito (bajar en < 1 s, cadera caída) | ≥ 80 % detectados, ≤ 10 % de falsos avisos |
| E2E | Playwright con *fake media stream* (video sintético) | La serie se rellena y se guarda |

## 10. Entregas

| Hito | Contenido | Disparador / criterio de "hecho" |
|---|---|---|
| **V1.0** | `lib/pose` + fuente MediaPipe + reglas de sentadilla a silla y wall sit + pantalla mínima + `form` en la serie | Pasan las pruebas de la §9 para esos 2 ejercicios |
| **V1.1** | Flexión, plancha y puente + voz + calibración | Mismas pruebas para los 5 ejercicios |
| **V1.2** | Prueba de nivel guiada + split squat, equilibrio y sit-and-reach | La prueba completa en < 25 min y propone fase y niveles |
| **V2.0** | `contrib/kinect-bridge` + fuente Kinect | Disparador de la §3.1 |
| **V2.1** | Progresión por variante usando `form.score` (subir de nivel solo si la técnica es ≥ 80) | Ligado a F5 "progresión por variante" |

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Conflictos con el upstream (si D-0 = seguir al original) | Todo en archivos nuevos (`lib/pose/`, `views/PoseCoach.jsx`). Las únicas modificaciones a archivos existentes son el botón en la serie y el campo `form`, mínimos y candidatos a PR upstream |
| Peso del bundle | Lazy import y WASM cargado solo al abrir la cámara; se mide con `scripts/bundle-size.mjs` |
| WebView de Capacitor sin permiso de cámara | Añadir los permisos de Android (`CAMERA`) e iOS (`NSCameraUsageDescription`) y probar en un dispositivo real |
| Kinect: adaptador y SDK solo para Windows | El bridge es opcional; la v1 no depende de él |
| Falsa seguridad ("la app dijo que estaba bien") | Texto en la interfaz: guía de técnica, no evaluación clínica |

## 12. Preguntas abiertas

1. ¿Tu Kinect es **v2 (Xbox One)** o **v1 (Xbox 360)**? ¿Tienes el adaptador USB para PC?
2. ¿Dónde vas a entrenar: delante del PC con webcam, con el móvil en un trípode o delante de la TV? Esto define la fuente por defecto.
3. ¿Decisión D-0 del plan (seguir al upstream o divergir)? Afecta a cuánto se toca de `sheets.jsx`.
