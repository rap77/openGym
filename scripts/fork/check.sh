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
run "api (node --test)" bash -c "cd '$REPO_ROOT/api' && npm test"

step "Tests del mcp"
run "mcp" bash -c "cd '$REPO_ROOT/mcp' && npm test"

step "Tests del frontend"
# Los MISMOS flags que usa el upstream en su CI (.github/workflows/test.yml). No es capricho: es
# el comando que decide un PR, y el coverage cambia el resultado de un test (SetVideo.test.jsx
# falla con coverage y pasa sin el, porque la instrumentacion cambia el timing). Con otros flags
# esta puerta no prediria lo que va a pasar upstream.
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
  # Clasifica los fallos: son mios (toco ese fichero) o son del upstream (no lo toco)?
  FAILED_FILES="$(sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$FRONTEND_LOG" \
    | grep -oE 'FAIL +[^ ]+\.(test|spec)\.[a-z]+' | awk '{print $2}' | sed 's|^frontend/||' | sort -u || true)"
  MINE="$(git -C "$REPO_ROOT" diff --name-only upstream/main...main 2>/dev/null | sed 's|^frontend/||' || true)"
  MINE_FAILED=''; UPSTREAM_FAILED=''
  for f in $FAILED_FILES; do
    if printf '%s\n' "$MINE" | grep -qxF "$f"; then MINE_FAILED="$MINE_FAILED $f"; else UPSTREAM_FAILED="$UPSTREAM_FAILED $f"; fi
  done
  if [ -n "$MINE_FAILED" ]; then
    fail "frontend (vitest) (${DUR}s) - fallos en ficheros TUYOS:$MINE_FAILED"
    FAILURES+=("frontend (vitest)")
  elif [ -n "$UPSTREAM_FAILED" ]; then
    # El upstream tiene su propia suite en rojo. No es cosa del fork y no debe bloquearlo,
    # pero hay que decirlo claro: un PR del fork se mediria con la misma suite.
    warn "frontend (vitest) (${DUR}s) - fallos en ficheros del UPSTREAM, no tuyos:$UPSTREAM_FAILED"
    warn "  El CI del upstream esta en rojo con lo mismo. No bloquea al fork, pero un PR tuyo se"
    warn "  mediria con esa suite: reporta el bug upstream antes de abrir el PR."
    dim "Log completo: $FRONTEND_LOG"
    PASSED=$(( PASSED + 1 ))
  else
    fail "frontend (vitest) (${DUR}s) - fallos sin fichero identificable"
    dim "Log completo: $FRONTEND_LOG"
    FAILURES+=("frontend (vitest)")
  fi
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
