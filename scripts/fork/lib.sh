#!/usr/bin/env bash
# Utilidades compartidas por los scripts del fork (scripts/fork/*.sh).
# shellcheck shell=bash
#
# El upstream no tiene nada de esto: son ficheros nuevos del fork, en un directorio que el
# upstream nunca toca, asi que cada sync sale sin conflictos.

set -euo pipefail

FORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$FORK_DIR/../.." && pwd)"

# Color solo si la salida es una terminal: en un log de CI seria ruido con codigos de escape.
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'; C_INFO=$'\033[36m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_ERR=''; C_WARN=''; C_INFO=''; C_DIM=''; C_OFF=''
fi

log()  { printf '%s==>%s %s\n' "$C_INFO" "$C_OFF" "$*"; }
ok()   { printf '%s  OK%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s  !%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
fail() { printf '%s  X%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }
die()  { fail "$*"; exit 1; }
step() { printf '\n%s--- %s ---%s\n' "$C_INFO" "$*" "$C_OFF"; }
dim()  { printf '%s    %s%s\n' "$C_DIM" "$*" "$C_OFF"; }

# Los paquetes del repo que se instalan con npm ci. Raiz, api, frontend, mcp, e2e.
FORK_PACKAGES=(. api frontend mcp e2e)

# El repo pide una version de Node y con otra el upstream da fallos falsos: con Node 24 caen
# AdminCoach y coach-api.i18n (docs/fork/BASELINE.md, deuda D-B3). Se avisa y se intenta
# cambiar con nvm antes de rendirse.
require_node() {
  local want have
  want="$(tr -d ' \tv\r\n' < "$REPO_ROOT/.nvmrc")"
  [ -n "$want" ] || die "No se pudo leer la version de Node de .nvmrc"
  have="$(node -v 2>/dev/null | sed 's/^v//' || true)"
  [ -n "$have" ] || die "Node no esta en el PATH. Instala la version de .nvmrc ($want)."
  case "$have" in
    "$want".*) return 0 ;;
  esac

  if [ -s "${HOME}/.nvm/nvm.sh" ]; then
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
    if command -v nvm >/dev/null 2>&1 && nvm use "$want" >/dev/null 2>&1; then
      have="$(node -v | sed 's/^v//')"
      case "$have" in
        "$want".*) ok "Node $have (cambiado con nvm)"; return 0 ;;
      esac
    fi
  fi
  die "Node $have, pero el repo pide $want (.nvmrc). Con otra version el upstream da fallos falsos (docs/fork/BASELINE.md, D-B3). Fix: nvm use $want"
}

# Que paquetes han cambiado entre dos commits, para no reinstalarlo todo en cada sync.
# "raiz" es el paquete de la raiz del repo (sus package.json).
changed_packages() {
  local from="$1" to="$2"
  local changed
  changed="$(git -C "$REPO_ROOT" diff --name-only "$from" "$to" 2>/dev/null || true)"
  local p out=()
  for p in "${FORK_PACKAGES[@]}"; do
    if [ "$p" = "." ]; then
      if printf '%s\n' "$changed" | grep -qE '^(package\.json|package-lock\.json)$'; then out+=("$p"); fi
    else
      if printf '%s\n' "$changed" | grep -q "^$p/"; then out+=("$p"); fi
    fi
  done
  [ "${#out[@]}" -gt 0 ] && printf '%s\n' "${out[@]}"
  return 0
}

# npm ci en los paquetes indicados.
npm_ci_in() {
  local p
  for p in "$@"; do
    [ "$p" = "." ] && p=""
    step "npm ci en ${p:-raiz}"
    ( cd "$REPO_ROOT/$p" && npm ci ) || die "npm ci fallo en ${p:-raiz}"
  done
}
