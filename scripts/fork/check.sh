#!/usr/bin/env bash
# La puerta de calidad del fork: lo mismo que corre el CI, en una sola orden y en local.
# shellcheck shell=bash
#
#   scripts/fork/check.sh                 # todo: checks, tres suites y e2e
#   scripts/fork/check.sh --no-e2e        # sin la e2e (no hace falta Docker)
#   scripts/fork/check.sh --install       # npm ci antes de nada
#
# No es un fichero del upstream: vive en scripts/fork/, un directorio que el upstream nunca
# toca, asi que cada sync sale sin conflictos. El plan lo contempla en H2.4 (se descarto el
# workspace npm y se sustituyo por este script).
#
# Por que --maxWorkers=4 en el frontend y no el que toque: el test de media-sync reserva
# 200 MB + 150 MB de blobs en memoria, y con 12 workers en paralelo se queda sin memoria y
# caduca a los 5 s. Es la deuda D-B1/D-B4 del BASELINE, no un fallo de logica. Con 4 workers
# la suite entera pasa (10101/10101).

set -euo pipefail
# shellcheck source=scripts/fork/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN_E2E=1
DO_INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-e2e) RUN_E2E=0 ;;
    --install) DO_INSTALL=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "Opcion desconocida: $1" ;;
  esac
  shift
done

cd "$REPO_ROOT"
FAILURES=()
PASSED=0
START=$(date +%s)

run() {
  # run <etiqueta> <comando...>
  local label="$1"; shift
  local t0 t1 dur
  t0=$(date +%s)
  if "$@"; then
    t1=$(date +%s)
    dur=$(( t1 - t0 )); [ "$dur" -lt 0 ] && dur=0
    ok "$label (${dur}s)"
    PASSED=$(( PASSED + 1 ))
  else
    t1=$(date +%s)
    dur=$(( t1 - t0 )); [ "$dur" -lt 0 ] && dur=0
    fail "$label (${dur}s)"
    FAILURES+=("$label")
  fi
}

# Clasifica los fallos de una suite: son mios (toco ese fichero) o son del upstream?
#
# El fork no toca ni un fichero de frontend/ ni de api/, asi que ahi cualquier fallo es del
# upstream por definicion. Avisar de eso (y no bloquear) evita dos cosas: una puerta roja sin
# motivo y un sync que se queda a medias por un fallo que no es del fork.
#
# classify <log> <prefijo-en-el-log> <prefijo-en-el-diff> <etiqueta>
# El log y el diff usan rutas distintas (vitest imprime "src/..." relativo a frontend/, y el diff
# del repo lleva "frontend/src/..."), asi que se recortan con prefijos distintos para que ambos
# lados queden en la misma forma y la comparacion sea exacta.
classify() {
  local log="$1" logpfx="$2" diffpfx="$3" label="$4"
  local failed mine mine_failed upstream_failed f
  # Dos formatos: vitest escribe " FAIL  src/..." y node --test escribe
  # "location: '/ruta/absoluta/api/test/x.test.js:85:1'". Se pillan por separado y se unen.
  failed="$( { sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$log" \
    | grep -oE "FAIL +${logpfx}[^ ]*\.(test|spec)\.[a-z]+" \
    | grep -oE "${logpfx}[^ ]*\.(test|spec)\.[a-z]+"
    sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$log" \
    | grep -oE "location: '[^']*${logpfx}[^':]*\.(test|spec)\.[a-z]+" \
    | grep -oE "${logpfx}[^':]*\.(test|spec)\.[a-z]+"; } \
    | sed "s|^${logpfx}||" | sort -u || true)"
  mine="$(git -C "$REPO_ROOT" diff --name-only upstream/main...main 2>/dev/null \
    | sed "s|^${diffpfx}||" || true)"
  mine_failed=''; upstream_failed=''
  for f in $failed; do
    if printf '%s\n' "$mine" | grep -qxF "$f"; then mine_failed="$mine_failed $f"; else upstream_failed="$upstream_failed $f"; fi
  done
  if [ -n "$mine_failed" ]; then
    fail "$label - fallos en ficheros TUYOS:$mine_failed"
    FAILURES+=("$label")
  elif [ -n "$upstream_failed" ]; then
    warn "$label - fallos en ficheros del UPSTREAM, no tuyos:$upstream_failed"
    warn "  El upstream tiene su propia suite en rojo con lo mismo. No bloquea al fork, pero un PR"
    warn "  tuyo se mediria con esa suite: reporta el bug upstream antes de abrir el PR."
    dim "Log completo: $log"
    PASSED=$(( PASSED + 1 ))
  else
    fail "$label - fallos sin fichero identificable"
    dim "Log completo: $log"
    FAILURES+=("$label")
  fi
}

step "Entorno"
require_node
dim "Node $(node -v), npm $(npm -v), repo $REPO_ROOT"

if [ "$DO_INSTALL" -eq 1 ]; then
  npm_ci_in "${FORK_PACKAGES[@]}"
fi

step "Chequeos de CI (los mismos que .github/workflows/test.yml)"
run "check-locales"        bash -c "cd '$REPO_ROOT/frontend' && node scripts/check-locales.mjs"
run "check-source-strings" bash -c "cd '$REPO_ROOT/frontend' && node scripts/check-source-strings.mjs --strict"
run "catalogue/build"      bash -c "cd '$REPO_ROOT' && node scripts/catalogue/build.mjs --check"
run "coach assets"         bash -c "cd '$REPO_ROOT' && node scripts/build-coach-assets.mjs --check"
run "api docs"             bash -c "cd '$REPO_ROOT' && node scripts/build-api-docs.mjs --check"

step "Tests de la api"
API_LOG="$(mktemp)"
API_T0=$(date +%s)
if ( cd "$REPO_ROOT/api" && npm test ) > "$API_LOG" 2>&1; then
  API_T1=$(date +%s)
  DUR=$(( API_T1 - API_T0 )); [ "$DUR" -lt 0 ] && DUR=0
  ok "api (node --test) (${DUR}s)"
  PASSED=$(( PASSED + 1 ))
else
  API_T1=$(date +%s)
  DUR=$(( API_T1 - API_T0 )); [ "$DUR" -lt 0 ] && DUR=0
  classify "$API_LOG" "api/test/" "api/test/" "api (node --test) (${DUR}s)"
fi
rm -f "$API_LOG"

step "Tests del mcp"
run "mcp" bash -c "cd '$REPO_ROOT/mcp' && npm test"

step "Tests del frontend"
# Los MISMOS flags que usa el upstream en su CI (.github/workflows/test.yml). No es capricho: es
# el comando que decide un PR, y una puerta verde tiene que predecir lo que va a pasar upstream.
FRONTEND_LOG="$(mktemp)"
FRONTEND_T0=$(date +%s)
if ( cd "$REPO_ROOT/frontend" && npx vitest run \
      --reporter=default \
      --coverage --coverage.provider=v8 --coverage.include='src/**' ) > "$FRONTEND_LOG" 2>&1; then
  FRONTEND_T1=$(date +%s)
  DUR=$(( FRONTEND_T1 - FRONTEND_T0 )); [ "$DUR" -lt 0 ] && DUR=0
  ok "frontend (vitest, como el upstream) (${DUR}s)"
  PASSED=$(( PASSED + 1 ))
else
  FRONTEND_T1=$(date +%s)
  DUR=$(( FRONTEND_T1 - FRONTEND_T0 )); [ "$DUR" -lt 0 ] && DUR=0
  classify "$FRONTEND_LOG" "src/" "frontend/src/" "frontend (vitest, como el upstream) (${DUR}s)"
fi
[ -n "${KEEP_FRONTEND_LOG:-}" ] || rm -f "$FRONTEND_LOG"

if [ "$RUN_E2E" -eq 1 ]; then
  step "Tests e2e (Playwright contra el stack aislado)"
  if ! command -v docker >/dev/null 2>&1; then
    warn "Docker no esta disponible: se saltan los e2e"
  else
    run "e2e" bash -c "cd '$REPO_ROOT' && e2e/run.sh --down"
  fi
fi

ELAPSED=$(( $(date +%s) - START ))
printf '\n'
if [ "${#FAILURES[@]}" -eq 0 ]; then
  ok "Todo en verde: $PASSED comprobaciones en ${ELAPSED}s"
  exit 0
fi
fail "${#FAILURES[@]} comprobacion(es) fallida(s) en ${ELAPSED}s:"
for f in "${FAILURES[@]}"; do printf '    - %s\n' "$f"; done
exit 1
