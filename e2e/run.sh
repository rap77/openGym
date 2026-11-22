#!/usr/bin/env bash
# Levanta el stack e2e aislado (puerto 8090), espera a que responda, corre Playwright y
# muestra el resultado. Uso:  e2e/run.sh                 (deja el stack arriba para inspeccionar)
#                             e2e/run.sh --down          (lo baja y borra sus datos al terminar)
#                             e2e/run.sh -- <args playwright>   (p. ej. -- --headed)
set -euo pipefail
cd "$(dirname "$0")/.."

DOWN=0
PW_ARGS=()
for a in "$@"; do
  if [ "$a" = "--down" ]; then DOWN=1; elif [ "$a" != "--" ]; then PW_ARGS+=("$a"); fi
done

DC=(docker compose -p opengym-e2e -f docker-compose.yml -f e2e/compose.e2e.yml)

"${DC[@]}" up -d --build

echo "Esperando a http://localhost:8090/api/health ..."
for i in $(seq 1 60); do
  if curl -fsS http://localhost:8090/api/health >/dev/null 2>&1; then echo "stack listo (${i}s)"; break; fi
  if [ "$i" -eq 60 ]; then echo "el stack no respondió en 60 s"; "${DC[@]}" ps; exit 1; fi
  sleep 1
done

set +e
(cd e2e && npx playwright test "${PW_ARGS[@]}")
status=$?
set -e

if [ "$DOWN" -eq 1 ]; then "${DC[@]}" down -v; fi
echo "playwright exit=$status"
exit $status
