# fork-routines — tus rutinas personales

Ficheros del **fork** `rap77/openGym`, no del upstream. Aquí viven tus planes de entrenamiento,
escritos en el formato que openGym ya sabe leer.

## Cómo importarlo

1. Abre openGym (web o app) con tu perfil.
2. **Plan → ⋮ (menú) → Import plan file** y elige
   `atlas-movilidad-hipopresivos.opengym-plan.json`.
3. La hoja de importación te preguntará si quieres **añadir también el horario semanal**.
   Di que sí: es lo que reparte Atlas A/B/C, movilidad e hipopresivos entre los 7 días.

También puedes mandártelo a ti mismo: el fichero es un JSON plano, sin nada dentro que la
app no entienda.

## Qué trae

| Rutina | Emoji | Contenido | Cuándo |
|---|---|---|---|
| **Atlas A · Empuje** | 💪 | push up, pike push up, fondos en silla, reverse plank, side plank | lunes |
| **Atlas B · Tirón** | 🤸 | dominada, mentoniana, remo invertido, front lever, human flag | miércoles |
| **Atlas C · Pierna y core** | 🦵 | sentadilla, split squat, wall sit, L sit, hollow hold | viernes |
| **Movilidad diaria** | 🧘 | 10 ejercicios, 12 min | los 7 días |
| **Hipopresivos** | 🌙 | vacío abdominal, respiración diafragmática, suelo pélvico, hollow hold, dead bug, puente, pallof | dom, mar, jue, sáb |

**32 ejercicios, 13 holds, 19 series de reps, 8 con tempo Atlas.**

## El método Atlas, y cómo lo hace openGym

Charles Atlas no entrenaba "lento": entrenaba **repeticiones dinámicas con tensión estática en el
mismo set**, 10 series por ejercicio, y al dominarlas subía la carga.

openGym tiene las tres piezas, y encajan:

| Atlas | En openGym |
|---|---|
| 10 series por ejercicio | `sets: 10` |
| Al dominar el rango, sube la carga | Progresión **doble**: sube por el rango de reps al mismo peso y, al llegar al techo en todas las series, avisa para cambiar |
| La pausa Atlas (tensión estática) | **Tempo** de 4 cifras: `3-1-X-2` = 3 s bajando, 1 s de pausa abajo, sube rápido, **2 s apretando arriba** |
| Los estáticos | Modo **Tiempo** (`sec`) con **auto-hold**: el cronómetro arranca solo |
| Los negativos y las progresiones de estático | `negative front lever raise`, `chin up (isometric and negative)`, `negative dragon flag`, `scapular pull-up`, `planche press` |

### Lo que hace el motor, medido (no supuesto)

Verificado simulando sesiones contra `frontend/src/lib/progression.js`:

- **Rampas de reps.** En peso corporal el motor pide `reps` y **sube 1 rep cada vez que clavas el
  objetivo en todas las series**. Hay que acertar el número: si te pasas, espera ("came up short",
  "same target again"). El ritmo real es ~1 rep cada 2 sesiones limpias.
- **El techo.** Con `repsMax` igual al objetivo (10), el día que completas 10×10 limpias la app
  dice literalmente: *"10 sets of 10. Time to add weight or try a harder variation."* Ese es el
  final exacto del método Atlas.
- ** bodyweight no sube peso.** En un ejercicio sin carga no hay "sube 2,5 kg": se progresa en reps
  o se cambia de variante.
- **Estáticos.** Con la progresión `time`, la app **suma 5 s por sesión** mientras aguantes todas
  las series enteras, y se queda quieta si te quedas corto.
- **`repsMin` no hace nada en peso corporal.** Solo afecta a ejercicios con carga. Por eso este
  fichero **no** lo usa: es el motor el que te sube el rango, no el fichero.

### Escala antes de empezar

Atlas hacía 10×10 de todo, pero después de años. Este plan **empieza donde puedes hoy**:

- Dominada: **3 reps** (el motor te sube hasta 10 solo).
- Mentoniana: 5. Pike push up: 5. Split squat: 5. Fondos: 8.
- Flexiones y sentadilla: 10 de salida.

Si la dominada a 3 no te sale, cambia el ejercicio por **0970 band assisted pull-up** o
**9511 box assisted pull up** y vuelve a 3.

## Los hipopresivos

**El catálogo de openGym no tiene hipopresivos** (0 de 5632). Lo que sí trae es el principio y
la parte respiratoria, y es lo que usa esta rutina:

- **5445 standing abdominal vacuum** → el vacío abdominal de pie: el núcleo del hipopresivo, con
  progresión de +5 s por sesión.
- **9977 lying supine abdominal breathing** → respiración diafragmática (4 s inspire, 8 s espire).
- **8146 lying pelvic floor relaxation and deep breathing** → suelo pélvico y respiración profunda.
- **1246 hollow hold** → el transverso en carga.
- **0276 dead bug**, **0142 bridge**, **0979 pallof** → anti-extensión y anti-rotación.

**Para el hipopresivo de verdad** (el de 30 s con 3-4 respiraciones resistidas) la app tiene la
herramienta: un **ejercicio personalizado con tu propio vídeo**.

1. En la app: Library → *Add exercise* → nombre "Hipopresivo", parte del cuerpo abdomen,
   y en el campo de media **subes el vídeo que tú grabes**.
2. Se re-codifica, se guarda en el servidor (`DATA_DIR/uploads`) y se sincroniza a todos tus
   dispositivos.
3. Añádelo a la rutina "Hipopresivos" desde Plan → Rutinas → editar → *Add exercise*.

El vídeo no viaja en este JSON: un plan no puede llevar media porque el formato solo admite ids
del catálogo. Por eso los ejercicios con tu vídeo van en la app, no en el fichero.

## Por qué esto es un plan file y no una entrada de la biblioteca

El upstream tiene una biblioteca de rutinas (`routines/`, `docs/ROUTINES_LIBRARY.md`) que se
configura por instancia en **Ajustes → AI Coach → Advanced → Routines library**. Es el mecanismo
barato para tener rutinas propias sin tocar código.

**Pero ese formato es de descubrimiento, no de prescripción.** `api/coach/core/routine-library.js`
(`entryToBundle`) solo conserva `id`, `sets`, `reps`/`sec` de cada ejercicio: **descarta la
progresión y el tempo**.

Para una rutina Atlas eso sería perder el método entero. Por eso:

- **Rutinas con método** (progresión, tempo) → **plan file** (este). Importar por Plan.
- **Rutinas sin método** (una lista de ejercicios) → entrada de índice, para que el Coach las
  sugiera y las ofrezca como tarjeta "Add to my plan".

Si algún día quieres que el Coach sugiera estas rutinas, habría que publicarlas como índice
aceptando que llegan sin `prog` ni `tempo`.

## Ficheros

- `atlas-movilidad-hipopresivos.opengym-plan.json` — el plan. Formato `opengym_plan: 1`.
  Validado con el parser del propio openGym (`parsePlan` + `mergePlan`): 5 rutinas, 32 ejercicios,
  0 descartados, 7 días, y la progresión y el tempo sobreviven a la importación.
