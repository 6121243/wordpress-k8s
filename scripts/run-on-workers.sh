#!/usr/bin/env bash
# Copie un script du master vers chaque worker (scp), l'exécute (ssh)
# et affiche la sortie de chaque worker sur le master.
#
# Usage : ./scripts/run-on-workers.sh [--sudo] <script> [arguments...]
#   ex. : ./scripts/run-on-workers.sh scripts/remote/check-node.sh
#         ./scripts/run-on-workers.sh --sudo scripts/remote/install-nfs-client.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory

SUDO=""
if [[ "${1:-}" == "--sudo" ]]; then SUDO="sudo"; shift; fi
SCRIPT="${1:?Usage : $0 [--sudo] <script> [args...]}"; shift
[[ -f "$SCRIPT" ]] || die "Script introuvable : $SCRIPT"

NAME="$(basename "$SCRIPT")"
REMOTE="/tmp/$NAME"
FAIL=0

for w in $WORKERS; do
  echo "================================================================"
  echo ">>> Worker $w — $(date '+%Y-%m-%d %H:%M:%S') — $NAME"
  echo "================================================================"
  if scp -q -o BatchMode=yes "$SCRIPT" "$SSH_USER@$w:$REMOTE" \
     && ssh -t -o BatchMode=yes "$SSH_USER@$w" "chmod +x $REMOTE && $SUDO $REMOTE $* ; rc=\$?; rm -f $REMOTE; exit \$rc"; then
    ok "$w : exécution réussie"
  else
    warn "$w : échec"
    FAIL=1
  fi
  echo
done
exit $FAIL
