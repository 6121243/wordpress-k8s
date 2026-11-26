#!/usr/bin/env bash
# Restaure une sauvegarde produite par le CronJob mysql-backup.
# Usage : ./scripts/restore-db.sh                      -> liste les sauvegardes
#         ./scripts/restore-db.sh <fichier.sql.gz>     -> restaure
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory
DIR="$NFS_PATH/backups"

if [[ -z "${1:-}" ]]; then
  info "Sauvegardes disponibles dans $DIR :"
  ls -lh "$DIR"/wordpress-*.sql.gz 2>/dev/null || warn "Aucune sauvegarde"
  exit 0
fi
FILE="$1"; [[ -f "$FILE" ]] || FILE="$DIR/$1"
[[ -f "$FILE" ]] || die "Fichier introuvable : $1"

read -r -p "Restaurer $FILE (la base actuelle sera écrasée) ? (oui/non) " ans
[[ "$ans" == "oui" ]] || die "Annulé"
gunzip -c "$FILE" | kubectl -n "$NAMESPACE" exec -i deploy/mysql -- \
  sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
ok "Base restaurée depuis $FILE"
