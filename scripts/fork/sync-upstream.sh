#!/usr/bin/env bash
# Sync del fork con el upstream: fetch, rebase, instalar lo que cambio y pasar la puerta de
# calidad. Es la operacion que hay que repetir cada 1-2 semanas, cuando el upstream publica.
# shellcheck shell=bash
#
#   scripts/fork/sync-upstream.sh              # sincroniza, verifica y se para
#   scripts/fork/sync-upstream.sh --push       # ademas sube el resultado a origin/main
#   scripts/fork/sync-upstream.sh --no-e2e     # sin la e2e (no hace falta Docker)
#
# Por que rebase y no merge: los commits del fork son solo adiciones de ficheros nuevos
# (FORK.md, docs/fork/, e2e/, fork-routines/), asi que no pueden chocar con el upstream y el
# rebase deja main lineal encima de upstream/main. Cada sync futuro rebasa solo los commits
# nuevos. Por eso el push necesita --force-with-lease.
#
# Que hace el upstream y cuando: docs/fork/PLAN-MEJORAS.md (D-0: seguir al upstream).

set -euo pipefail
# shellcheck source=scripts/fork/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PUSH=0
RUN_E2E=1
while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1 ;;
    --no-e2e) RUN_E2E=0 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "Opcion desconocida: $1" ;;
  esac
  shift
done

cd "$REPO_ROOT"

step "Preflight"
# Un cambio a un fichero ya versionado se perderia en el rebase: ahi si se para. Un fichero
# sin versionar no se pierde, pero choca si el upstream trae uno del mismo nombre, y eso se
# comprueba despues, con la lista de ficheros del upstream ya traidos.
MODIFIED="$(git status --porcelain | grep -vE '^\?\?' || true)"
UNTRACKED="$(git status --porcelain | grep -E '^\?\?' | sed 's/^?? //' || true)"
if [ -n "$MODIFIED" ]; then
  git status --short
  die "Hay cambios sin commitear en ficheros ya versionados. Commit o stash antes de sincronizar."
fi
if [ -n "$UNTRACKED" ]; then
  warn "Ficheros sin versionar (el rebase no los toca, pero los reviso luego):"
  for f in $UNTRACKED; do dim "$f"; done
fi
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || die "Este script se usa en la rama main."
if ! git remote get-url upstream >/dev/null 2>&1; then
  die "No esta el remoto 'upstream'. Anadelo con: git remote add upstream https://github.com/DuarteSantos8/openGym.git"
fi
ok "Repo limpio, en main, con remoto upstream"
require_node

OLD_HEAD="$(git rev-parse HEAD)"

step "Traer el upstream"
git fetch upstream --filter=blob:none
git fetch origin --filter=blob:none
AHEAD=$(git rev-list --count "$OLD_HEAD"..upstream/main)
BEHIND=$(git rev-list --count upstream/main.."$OLD_HEAD")
dim "El fork tiene $BEHIND commit(s) propios; el upstream trae $AHEAD."
TAG="$(git tag -l 'v*' --sort=-v:refname | head -1)"
[ -n "$TAG" ] && dim "Ultima release del upstream: $TAG"

# Un fichero sin versionar que el upstream trae del mismo nombre haria fallar el rebase.
if [ -n "$UNTRACKED" ]; then
  INCOMING="$(git diff --name-only "$OLD_HEAD" upstream/main || true)"
  for f in $UNTRACKED; do
    if printf '%s\n' "$INCOMING" | grep -qxF "$f"; then
      die "El upstream trae '$f' y tu tienes un fichero sin versionar con ese nombre. Renombralo o commitalo antes de sincronizar."
    fi
  done
fi

if [ "$AHEAD" -eq 0 ]; then
  ok "Ya estas al dia con upstream/main. No hay nada que hacer."
  exit 0
fi

step "Rebase sobre upstream/main"
BACKUP="backup/pre-sync-$(date +%Y%m%d-%H%M)"
git branch "$BACKUP" "$OLD_HEAD"
dim "Red de seguridad: rama $BACKUP -> $(git rev-parse --short "$BACKUP")"

if ! git rebase upstream/main; then
  CONFLICTS="$(git diff --name-only --diff-filter=U)"
  git rebase --abort || true
  fail "El rebase tiene conflictos. Se ha abortado: el repo queda como estaba."
  for f in $CONFLICTS; do printf '    conflicto: %s\n' "$f"; done
  dim "Un conflicto aqui significa que un commit del fork ya toca un fichero del upstream."
  dim "Esa es la senal de que esa funcionalidad deberia ir upstream, no en el fork."
  die "Resuelve el conflicto a mano o descarta el cambio en ese fichero."
fi
NEW_HEAD="$(git rev-parse HEAD)"
ok "Rebase limpio: $(git rev-parse --short "$OLD_HEAD") -> $(git rev-parse --short "$NEW_HEAD")"

step "Instalar lo que cambio"
PKGS="$(changed_packages "$OLD_HEAD" "$NEW_HEAD")"
if [ -n "$PKGS" ]; then
  dim "Paquetes afectados: $(echo "$PKGS" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  npm_ci_in $PKGS
else
  dim "Ningun paquete cambio: no hace falta reinstalar."
fi

step "Puerta de calidad"
if [ "$RUN_E2E" -eq 1 ]; then
  bash "$REPO_ROOT/scripts/fork/check.sh"
else
  bash "$REPO_ROOT/scripts/fork/check.sh" --no-e2e
fi
CHECK=$?

if [ "$CHECK" -ne 0 ]; then
  fail "La puerta de calidad fallo. NO se sube nada."
  dim "El rebase ya esta hecho y el repo esta en el estado nuevo, para que veas que rompio."
  dim "Arreglalo y repite el push a mano: git push --force-with-lease origin main"
  dim "Para volver atras: git reset --hard $OLD_HEAD  (o checkout $BACKUP)"
  exit 1
fi

if [ "$PUSH" -eq 1 ]; then
  step "Subir a origin/main"
  git push --force-with-lease origin main
  ok "Subido. El lease habria fallado si origin/main se hubiera movido."
else
  step "Resumen"
  ok "Todo en verde. El cambio esta en local, todavia sin subir."
  dim "Para subirlo: git push --force-with-lease origin main"
fi
dim "Red de seguridad en la rama $BACKUP (local; borrala cuando quieras: git branch -D $BACKUP)"
