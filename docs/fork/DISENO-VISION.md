# Design: computer-vision exercise supervision (openGym fork)

**Status:** v0.2 · the pivot edition · 27-nov-2026 · Author: Rafael Padrón
**Supersedes:** the v0.1 draft (8-nov-2026) in this file. v0.1 proposed a fork-owned pose engine; that design is obsolete.
**Related:** [PLAN-MEJORAS.md](PLAN-MEJORAS.md) (§F5-bis.2) · [BASELINE.md](BASELINE.md) · [FORK.md](../../FORK.md) · Programme: vault `fitness-knowledge/06-programas/` · Research: vault `fitness-knowledge/04-tecnologia/computer-vision-pose-estimation.md`

## 1. Objective

The app takes control of the home session, without paper:

1. Count reps and time holds automatically.
2. Measure tempo (target: 3 s on the way down) and detect technique errors, with a spoken warning.
3. Run the **level test** alone and propose a starting level for each pattern.
4. Store what was measured in the set, for progression and the coach.

**Out of scope for v1:** clinical diagnosis, loaded gym exercises, several people in frame, floor exercises seen from above.

### 1.1 Who owns what after the pivot

| Objective | Upstream (PR #1560 and #1576) | This fork |
|---|---|---|
| 1. Count reps, time holds | ✅ 15 drills, plus 8 more in #1576. The tracker returns `count`, and the counted reps are the ones that go into the set's averages | The pose source that feeds those drills: MediaPipe, in the browser (§5) |
| 2. Tempo and technique errors | ✅ per-rep `misses` with a `reason`, tempo in the result, one spoken `cue` at the end | The source's own bias: the thresholds need a per-source retune (§6) |
| 3. Level test alone | ❌ nothing in #1560 | ✅ the fork, in V5 |
| 4. Store what was measured | ✅ the counted reps go into the set's averages; the result carries the per-rep `details` | The exercises upstream deliberately leaves out (hip thrust, balance, sit-and-reach) |

## 2. Principles (kept from v0.1)

- **Everything on device.** The video never leaves the device and only numbers are stored (reps, times, score). Consistent with openGym (no telemetry).
- **One pose interface, several sources.** The exercise logic does not know where the points come from (adapter pattern). After the pivot this principle is upstream's: the drill code does not know that MediaPipe exists.
- **Rules as data.** After the pivot: the rules are upstream's, in JavaScript, one file per drill, with a test file beside it.
- **Optional.** A module that is off by default; nothing is loaded until the camera opens (lazy import).
- **No silent calibration.** After the pivot: the thresholds come from upstream and are never quietly retuned. A per-source retune is an explicit, versioned change (D-4).

## 3. What changed and why (the pivot)

### 3.1 The upstream state (27-nov-2026)

| Upstream | State |
|---|---|
| **PR #1560** "Form check (iPhone): the camera counts your reps and refuses the ones that miss the standard", author `bluzername`, opened 25-nov-2026, updated 27-nov-2026 | OPEN, MERGEABLE · 19,151 additions / 4 deletions / 80 files changed. The branch is `form-check-pr`, and it lives in the contributor's fork, not in upstream's repo. No human comment yet, only a CodeRabbit bot review. The maintainer has not answered. The PR body says it was generated with Claude Code. |
| **PR #1576** "Form check: eight more drills (stacked on #1560)", author `bluzername`, opened 26-nov-2026 | OPEN, stacked on #1560. Eight drill files (front raise, upright row, straight-arm pulldown, hanging leg/knee raise, seated cable row, wall sit, hip abduction and one more), each with its test file, its strings and its tuning commits; 84 catalogue rows gain a drill. Its body says: if #1560 is declined, close #1576 too. |
| **Issue #920** "Jump rope block in a workout: jumps counted by the Apple Watch, AirPods or camera, hands-free intervals and a live screen with heart rate and records", author `pascalplr`, opened 29-oct-2026 | OPEN |

What #1560 does:

- **Fifteen drills:** squat, split squat, Romanian deadlift, pull-up/chin-up, inverted row, chest-supported row, rear fly, push-up, dip, overhead press, triceps pushdown, curl, lateral raise, plank, side plank.
- **Deliberately left out,** because one 2D camera cannot judge them: deadlift from the floor, bench press, hip thrust, bent-over row, dead bug, machine fly, walking lunges.
- **The exercise logic is JavaScript; only the camera/pose source is native** (`FormCheckPlugin.swift`). The drill files, the sheets, the stored standard and the page glue are all JS.
- **Its own words:** "Android and the web are untouched: the entry only shows where the plugin answers."

Files it touches (for reference, upstream's): `frontend/ios/App/App/FormCheckPlugin.swift`, `frontend/src/lib/form-check-native.js`, `frontend/src/lib/form-check-standard.js`, `frontend/src/lib/form-drills/**` (one file per drill, a test file per drill, plus `README.md`, `index.js`, `kit.js` and `test-kit.js`), `frontend/src/components/FormCheckSheet.jsx`, `frontend/src/components/Media.jsx`, `frontend/src/views/Workout.jsx`, `frontend/src/index.css`, plus the 25 locales.

### 3.2 The pivot

**D-1 (27-nov-2026): the fork pivots to the upstream contract.** The fork stops writing its own engine and instead writes a **second pose source** (MediaPipe, in the browser) that feeds the **same** upstream drill contract.

Why:

- **One codebase for Android + web + desktop.** The upstream source is native iOS. A browser source covers the web app, the Android app and the desktop browser with the same code.
- **Upstreamable instead of fork-only.** A source that plugs into an existing contract is a pull request upstream can take. A second engine is a fork that never converges.
- **v0.1 duplicated what upstream now has.** The fork's own `rules/<exerciseId>.json`, `engine.js`, `angles.js`, `smoothing.js` and `calibrate.js` would have been a second implementation of the same drills, with its own thresholds, its own tests and its own bug list.
- **Nothing is thrown away.** The fork has written zero vision code so far: there is no `frontend/src/lib/pose/` and no `frontend/src/views/PoseCoach.jsx` in the repo.

### 3.3 v0.1 → v0.2, section by section

| v0.1 | v0.2 |
|---|---|
| §4 architecture (`lib/pose/` with `engine.js`, `rules/`, `angles.js`, `smoothing.js`, `calibrate.js`) | Dropped. The drill contract is upstream's (§4) and the fork's only file group is the source (§5) |
| §4.1 common skeleton model (`{ t, source, joints }` with `shoulderL`-style names) | Replaced by the upstream frame shape (§4.2) |
| §4.2 own state machine (phases, hysteresis, events) | Replaced by upstream's phase machine in `kit.js` (`createPhaseMachine(thresholds)`) |
| §4.3 own rule JSON format | Replaced by upstream's drill definition (§4.1) |
| §5 own exercise table | Upstream covers 15 drills; the fork keeps the level test and the exercises upstream leaves out (§7, V5) |
| §6 new `form` field in the set | Upstream's sheets already write the counted reps and the per-rep details |
| §7 own camera screen (`views/PoseCoach.jsx`) | The fork's own web/Android screen, in V3, fed by the fork's source |
| §9 acceptance tests | Replaced by the fork's own fixtures: recorded MediaPipe frames per drill (§6) |
| §10 milestones V1.0 / V1.1 / V1.2 | Replaced by V0…V5 (§7) |
| §11 risks | Replaced by the honest risks of the pivot (§6) |
| §12 decisions | D-1…D-7 (§8) |

## 4. The contract the fork builds against

Quoted from upstream's `frontend/src/lib/form-drills/README.md` (in #1560), so this document is self-contained.

> Everything around a drill is drill-agnostic: the page glue (`lib/form-check-native.js`), the sheets (`components/FormCheckSheet.jsx`), the stored standard (`lib/form-check-standard.js`) and the Workout entry (`views/Workout.jsx`, where "Form check" shows on an exercise when `drillFor(ex)` finds a drill). **A drill MEASURES, it never grades.**

### 4.1 The drill definition

```js
{
  id: 'squat',                  // lower-case letters, digits, dashes; also the stored-standard key
  name: 'Squat',                // English key for t()
  kind: 'reps',                 // 'reps' | 'hold'
  views: ['side', 'front', 'diagonal'], // camera angles it can judge, best first
  setup: 'Phone at knee height and level, ...', // English key for t(): how to stand
  matches(ex),                  // catalogue exercise { id, n, cat } -> boolean; id allow-list + guarded name test
  standards: [{ id: 'parallel', label: 'Parallel' }, ...], // label: English key for t()
  defaultStandard: 'parallel',
  misses: { shallow: { line: 'Too shallow. Not counted.', say: 'Too shallow', row: 'Not counted: too shallow' } },
  create({ standard, view }),   // -> tracker
}
```

### 4.2 The frame

`tracker.push(frame)` is called about 15 times a second with one frame:

```js
frame = { t: 1234,              // ms, the camera clock
          aspect: 0.75,         // image width / height; stretch x by it before any distance or angle
          joints: { leftHip: [x, y, conf], ... } } // normalised, y down; only joints Vision saw
                                // (nose, neck, left/right Shoulder Elbow Wrist Hip Knee Ankle, root)
```

### 4.3 What the tracker returns

Every frame: `count` (counted reps so far; for `hold`, whole seconds held in good position), `phase` (`'waiting' | 'standing' | 'descending' | 'bottom' | 'ascending'`, or the drill's own), `inFrame` (false when the frame cannot be judged), `hint` (the translated status line), `justCounted` (true on the one frame a rep is counted), `justMissed` (true on the one frame a rep ends without counting), `reason` (with `justMissed`: a key of `misses`), `reached` (the rep under way already meets the standard), `highlight` (the joint names the overlay draws large and green now, usually `reached ? [...] : []`).

`tracker.result()`: `count`, `missed`, `reps` (array of `{ counted, reason, lost, measures }` per rep in order, no-reps included; `lost` = the camera lost the lifter mid-rep), `tiles` (0-3 headline stats `{ id, label, value, sub? }`), `cue` (the one translated sentence the result ends with), `cueId`, `details` (per rep, same order as `reps`, a list of `{ label, value }` for "Every rep"), `note`. A drill may add fields of its own; only the fields above are read by the sheets.

### 4.4 The rules every drill keeps

- Counted reps only in `count` and in the set's averages; no-reps stay in `reps` with `counted: false`.
- A rep the camera lost for a moment counts (flagged `lost`); one lost longer than `LOST_RESET_MS` is dropped.
- Measure only what the view can show.
- Strings are translated at call time, never at import.

### 4.5 The shared kit and the test kit

`kit.js`: `seen`, `mid`, `dist`, `angleAt`, `deg`, `ema`, `mean`, `round1`, `spread`, `fades`, `chainConf`, `pickSide`, `createSidePicker`, `widthRatio`, `createViewDetector`, `detectView`, `framing`, `framingHint`, `viewHint`, `createPhaseMachine(thresholds)`, `tempo(rec)`, `pickCue(rules)`, `matchExercise(ex, rule)`.

`test-kit.js` films a 3D stick figure through a pinhole camera (2.6 m away, knee height, level, 64-degree vertical field, 3:4 portrait) into the frames the plugin emits, with options `noise`, `drop`, `gap: [from, to]`, `height`, `pitch`, `dist`, `seed`. It can yaw the camera (0 = side-on, 90 = facing the camera) and the far side's confidence falls the more side-on the view is.

The squat drill reads image-vertical signals: the hip's drop from standing over the standing leg, and the hip's height against the knee's. Vision's hip sits on the pelvis, about 0.2 thigh lengths above the hip crease at the bottom of a squat, so a squat to parallel reads the hip above the knee; side-on it adds the knee angle, its spread and the torso lean; from the front, knees caving in and hips shifting sideways; at an angle, count, depth and tempo only. Depth is judged only with the phone at knee height and level, outside a side view.

Adding a drill = one file + one test file + one import line in `form-drills/index.js` + its strings in every locale (`src/locales/*.js`, pt-BR overrides in `PT_BR_OVERRIDES` when it differs). `index.test.js` runs every registered drill through `checkDrill()`, checks its declared strings in every locale and pushes an empty frame through it.

### 4.6 The fork does not fork this code

**The fork consumes upstream's contract, it does not copy it.** Once #1560 lands, the fork's source imports the drills from `frontend/src/lib/form-drills/` and only adds the source that feeds them. A copy in the fork would be exactly the divergence D-0 = A forbids, and it would be the fallback in §6 only if the maintainer declines the PR.

## 5. The MediaPipe source (the fork's actual work)

### 5.1 The package and the API

```js
import { FilesetResolver, PoseLandmarker } from "@mediapipe/tasks-vision";

const vision = await FilesetResolver.forVisionTasks("<url>/wasm");
const landmarker = await PoseLandmarker.createFromOptions(vision, {
  baseOptions: { modelAssetPath: "pose_landmarker_lite.task", delegate: "GPU" },
  runningMode: "VIDEO",
  numPoses: 1,
});
```

The live camera loop is the documented pattern: `getUserMedia` → `<video>` → `detectForVideo(video, performance.now())` inside a `requestAnimationFrame` loop, skipping frames when the previous detection is still busy.

The output is a `PoseLandmarkerResult`: `landmarks` = 33 keypoints per pose normalised to [0,1] (x and y normalised by image width and height; z is depth relative to the midpoint of the hips; each point carries `visibility` and `presence` in [0,1]); `worldLandmarks` = the same 33 points in metres with the hip midpoint as origin; `segmentationMasks` optional.

### 5.2 The mapping onto the contract's joint names

MediaPipe has no neck and no root, so those two are computed. Every other name maps 1:1.

| MediaPipe landmark | Index | Contract joint |
|---|---|---|
| nose | 0 | `nose` |
| left_shoulder | 11 | `leftShoulder` |
| right_shoulder | 12 | `rightShoulder` |
| left_elbow | 13 | `leftElbow` |
| right_elbow | 14 | `rightElbow` |
| left_wrist | 15 | `leftWrist` |
| right_wrist | 16 | `rightWrist` |
| left_hip | 23 | `leftHip` |
| right_hip | 24 | `rightHip` |
| left_knee | 25 | `leftKnee` |
| right_knee | 26 | `rightKnee` |
| left_ankle | 27 | `leftAnkle` |
| right_ankle | 28 | `rightAnkle` |
| midpoint of 11 and 12 | — | `neck` (MediaPipe has none) |
| midpoint of 23 and 24 | — | `root` (MediaPipe has none) |

MediaPipe also has joints Vision lacks: eyes (1-6), ears (7, 8), mouth (9, 10), hands (17-22), heels (29, 30) and foot index (31, 32). The drills work in 2D, so those points are **not emitted**.

- **Confidence:** the landmark's `visibility`, with `presence` as the fallback when `visibility` is absent.
- **The `aspect` correction:** the frame's `aspect` is the video's width / height, and the contract wants x stretched by it. That is exactly the correction MediaPipe's width-normalised x needs, so the source only has to publish `aspect` and let the contract do the rest.
- **The clock:** the frame's `t` is the camera clock in ms, which is `performance.now()` in the same loop.

### 5.3 Serving the model and the WASM

The model (`pose_landmarker_lite.task`, about 6-9 MB) and the WASM fileset are served by the **fork's own nginx**, never from a CDN, following the `/exercise-media/` pattern: a new static folder under the web image. The service worker (`frontend/public/sw.js`) can cache them, the same way it caches the media.

The nginx template and the Dockerfile that copy the media folder are upstream's files, so this lands in the same upstream pull request as the source, or the assets ride in `frontend/public/` and the existing nginx serves them without a config change.

**Lazy import:** the screen imports `@mediapipe/tasks-vision` dynamically when the camera opens, so the bundle does not grow until the user asks for the camera.

### 5.4 The proposed layout (fork's own files, all new)

```
frontend/src/lib/pose/           ← pure, no React, testable
  mediapipe.js       the source: getUserMedia → PoseLandmarker → frames in the contract shape
  landmarks.js       MediaPipe index → joint name (neck = shoulder midpoint, root = hip midpoint)
  mediapipe.test.js  unit tests with recorded MediaPipe frames
  fixtures/*.json    recorded MediaPipe frames, one set per drill the fork claims
frontend/src/views/FormCheckWeb.jsx   ← the fork's own camera screen (V3)
```

The file names above are a proposal, not a fact: upstream's names are fixed by #1560, the fork's are not.

### 5.5 The strings and the 25 supported locales

**Every user-facing string of this feature ships in all 25 supported locales.** This is not a
nice-to-have and it is not optional: the repository's own gates enforce it.

How the repo's i18n works (read from `frontend/src/locales/` and `frontend/scripts/`):

- **English is the source language and has no pack.** The key IS the English string, so a new
  string is written in English in the source and then translated into the 25 packs
  (`ar, bn, cs, da, de, es, fa, fr, hi, hu, id, it, ko, lt, pl, pt, pt-BR, ru, sv, th, tr, uk,
  vi, zh, zh-TW`).
- **The reference is the union of all locales**, not one blessed file. A key that exists in only
  some packs flags the others instead of passing unnoticed, because a missing key falls back to
  English **silently, mid-sentence**, with every check green.
- **The gates:** `node scripts/check-locales.mjs` (key present, not blank, `{n}` placeholders
  preserved as a multiset) and `node scripts/check-source-strings.mjs --strict` (a `t()` literal
  that no pack defines fails the build). Both run in CI.
- **pt-BR inherits from pt.** It only carries `PT_BR_OVERRIDES` for the wording that must differ,
  and `scripts/pt-br-inheritance-fingerprint.mjs` fingerprints every deliberately inherited entry
  so an upstream change forces a review.
- **Counts need plural forms.** `tn('{0} second', '{0} seconds', n)`, not `t()`, because
  Lithuanian, Russian, Ukrainian and Polish have plural forms where a count sits in the string.
- The only sanctioned escape hatch is `italianOnlyKeys` in `check-locales.mjs`, a deliberate list
  for one Italian-only API-error copy. It lives in an upstream file, so the fork does not extend it.

**The rule that saves most of the work: do not write new strings for the drill vocabulary.**
Upstream already translated the drill names, the setup lines, the standards and the misses into
the 25 packs. The fork's screen must **read them from the drill object** (`drill.name`,
`drill.setup`, `drill.standards[].label`, `drill.misses[].line/say/row`, `tracker.result().cue`,
`.tiles[].label`) and pass them through `t()`, never hardcode copy of its own. Then the fork's
web screen is translated for free and there is nothing new to translate.

Only the strings that are genuinely the fork's own (the web source's own hints) need 25
translations each, so they are kept to the minimum and reused across the screen. The cost of a
string in this fork is 25 translations (the packs went from 20 to 25 after the v1.4.5 sync), and
that is the reason to consume upstream's strings instead of rewriting them.

**A cheap first upstream contribution:** upstream's own PR says its translations are
machine-drafted and want native eyes. Once the strings land, the fork can do a native-eye pass
over the packs it knows best (`es.js` and `pt-BR.js`) and propose the corrections upstream. That
needs neither MediaPipe nor the merge of anything else.

## 6. Honest risks

**These are the reasons this pivot might fail. None of them is softened.**

### 6.1 The upstream thresholds do not transfer

The upstream thresholds were tuned against **Vision's** pose, including its hip marker: Vision's hip sits on the pelvis, about 0.2 thigh lengths above the hip crease at the bottom of a squat. MediaPipe's hip and its depth estimate are different. **The same thresholds will NOT transfer as they are.** Expect a per-source retune of every drill the fork claims, and expect the retune to be part of the work, not a detail.

### 6.2 The upstream test kit validates the drill code, not a pose source

`test-kit.js` films a synthetic 3D stick figure through a pinhole camera. It proves the drill logic is right; it says nothing about whether MediaPipe's points feed it correctly. The fork needs its own fixtures: **recorded MediaPipe frames (JSON) per drill it claims**, plus a real-camera session on a real device. A green upstream suite is not evidence for the fork's source.

### 6.3 The contract has no `source` dimension

`create({ standard, view })` cannot tell a drill which pose source it is running on. A second source with different biases most likely needs `create({ standard, view, source })` and per-source thresholds. **That is the first, smallest pull request to propose upstream** (D-4), and it is a change to upstream's files, so it needs the maintainer's yes.

### 6.4 The fork depends on an unmerged third-party pull request

**PR #1560 is still open**, nobody has answered, and it was generated with Claude Code. If the maintainer declines it, the fork's pivot has no contract to plug into, and #1576 says it should be closed too. The fallback is to propose the drills plus the MediaPipe source together upstream, or to keep the fork's own copy of the contract. The second fallback contradicts D-0 = A and needs an explicit decision.

### 6.5 A new dependency, against the dependency-light rule

`@mediapipe/tasks-vision` would be the **first** ML library in the frontend (today: React, react-router-dom, zustand, jsqr, leaflet and the Capacitor plugins). The model is about 6-9 MB and the WASM fileset adds to that. The fork's bundle baseline is **42,702 kB** after the v1.4.5 sync, so the download is a new thing the user has to accept on a phone connection. The lazy import keeps it out of the initial bundle; it does not make the download smaller.

### 6.6 Old Android WebViews may lack WebGL2

The GPU delegate needs WebGL2. On an old WebView the fallback is the **CPU delegate** or the lite model, and it needs a real device test. An emulator is not evidence.

### 6.7 MediaPipe's `z` and its extra joints do not fit the 2D contract

MediaPipe's depth estimate is a different estimate from Vision's, and the drills work in 2D (x stretched by aspect). The extra joints are not emitted and the `z` is not used. Any drill that later wants depth needs a contract change too.

### 6.8 The upstream source's own known limits are inherited

Upstream's own list, on its iPhone source: bench dips stopping 10-15 degrees short of level count as level; from the front a push-up counts without judging depth; lateral raise height is not judged with the phone above the shoulders; overhead press and chest-supported row have no footage of bad reps; inverted row has only three tuning clips. On top of that, the fork's source inherits none of the tuning clips: upstream tuned on 80/80 tuning clips and 40/40 held-back clips from real public exercise videos (used locally only), with at least two held-back and three tuning clips per drill. **The MediaPipe source starts with zero tuning material.**

## 7. Milestones

| Milestone | Content | Trigger / "done" criterion |
|---|---|---|
| **V0** | This document and the plan update | Done when `PLAN-MEJORAS.md` §F5-bis.2 and the status table name the pivot |
| **V1** | Track the upstream PR: the fork reads `form-check-pr` (and #1576) as read-only references and re-syncs when they land | The branch is in the fork's remote-tracking refs, never rebased onto, and the fork's quality gate runs the drills' own tests (`npx vitest run src/lib/form-drills`: 21 files, 1,065 tests) once the branch is in |
| **V2** | The MediaPipe source in the fork: a new `frontend/src/lib/pose/` (new files only) producing frames in the upstream contract shape, unit-tested against recorded MediaPipe fixtures | The source emits frames in the contract's shape and the unit tests pass against the recorded fixtures. **The thresholds do not transfer yet, so the drills do not count correctly yet**; that is V4 |
| **V3** | The web/Android camera screen: the fork's own glue and screen, because upstream's `form-check-native.js` is iOS-only, so the entry appears where the web source can answer | A real set is counted from the phone camera on web and on Android. The entry itself lives in upstream's `views/Workout.jsx`, a contact point for the upstream PR (D-7). Every string of the screen is in the 25 supported locales, the drill vocabulary is consumed from upstream's translated strings (§5.5), and `check-locales.mjs` plus `check-source-strings.mjs --strict` are green |
| **V4** | The upstream PR: the MediaPipe source plus the `source` dimension in the contract, with the fixtures | The pull request is open upstream with the fixtures attached, and the maintainer's answer is on the record |
| **V5** | The level test and the remaining home exercises: v0.1's `level-test.js`, sit-and-reach, split squat (per side, as in v0.1) and one-leg balance | The level test runs alone and proposes a level per pattern; each remaining exercise has a drill with its own test. Upstream already has a split-squat drill, so the fork's is the per-side variant, or a gap upstream left |
| **V2.0** | The Kinect bridge | **Deferred** (D-6). The owner has a Kinect v1 (Xbox 360); SDK 1.8 is Windows-only and unmaintained, tracking on the floor is poor, and it needs the "Kinect for Windows" adapter. The trigger to reopen it is unchanged from v0.1 §3.1: (a) more than 10 % false counts in the v1 acceptance tests because of depth, (b) wanting to supervise floor exercises (plank or bridge seen from the front), or (c) lighting problems where you train, **and** not solved by moving the phone or the light. First a Kinect v2 or a current depth camera is evaluated |

## 8. Decisions (27-nov-2026)

1. **D-1 · Pivot to the upstream contract.** The fork stops writing its own engine and writes a second pose source (MediaPipe, in the browser) that feeds the upstream drill contract. One codebase for Android + web + desktop, and upstreamable instead of fork-only.
2. **D-2 · The fork's source is MediaPipe in the browser, lite model, lazy-loaded.** `@mediapipe/tasks-vision` with `pose_landmarker_lite.task`, GPU delegate with a CPU fallback, served from the fork's own nginx (never a CDN). The module stays optional and off by default.
3. **D-3 · No own engine, no own rules, no own calibration in the fork.** v0.1's `engine.js`, `rules/<exerciseId>.json`, `angles.js`, `smoothing.js` and `calibrate.js` are dropped. The calibration v0.1 had moves upstream with the `source` dimension (D-4), or it waits.
4. **D-4 · The contract gets a `source` dimension and per-source thresholds, proposed upstream first.** `create({ standard, view, source })`. It is the first and smallest upstream pull request, and it is where the retune of §6.1 lands.
5. **D-5 · While #1560 is unmerged the fork tracks the branch and writes no engine.** The branch lives in the contributor's fork, so the fork reads it as a read-only reference and never rebases onto it. The MediaPipe source (V2) is a source, not an engine, and may be developed against the branch's contract shape; but no fork code that depends on the contract lands in `main` until the contract is upstream, because otherwise the fork's `main` would carry code that upstream does not have.
6. **D-6 · Kinect deferred.** The owner has a Kinect v1 (Xbox 360); SDK 1.8 is Windows-only and unmaintained, floor tracking is poor, and it needs the "Kinect for Windows" adapter. The v0.1 §3.1 bridge stays designed but not planned, and the reopen trigger is unchanged.
7. **D-7 · D-0 = A stays: no upstream file is edited in the fork.** The fork's files are new; the two upstream contact points are the **Workout entry** (`views/Workout.jsx`, where "Form check" shows) and the **catalogue's drill mapping** (the drill that each exercise matches). Both are candidates for the upstream pull request.
8. **D-8 · Every user-facing string ships in the 25 supported locales, and the drill vocabulary is consumed, not rewritten.** The fork reads the drill's name, setup, standards and misses from the drill object and passes them through `t()`, so the screen is translated for free; the fork's own strings are the minimum possible and land in all 25 packs, with `check-locales.mjs` and `check-source-strings.mjs --strict` green (§5.5).

## 9. Open questions

1. **Will the maintainer accept #1560 (and #1576)?** No human comment yet, only a CodeRabbit review, and the maintainer has not answered. This gates everything from V2 on.
2. **Do the upstream thresholds transfer to MediaPipe?** Unknown until a recorded fixture run. Expect a retune (§6.1).
3. **Does the CPU-delegate fallback work on an old Android WebView without WebGL2?** Needs a real device, not an emulator.
4. **Is the level test worth building before the Android screen?** V5 sits after V3 on purpose, but the level test is the piece the user would feel first at home, and it needs its own source to be useful.
