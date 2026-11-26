#!/usr/bin/env bash
# À lancer UNE fois sur le master : crée une clé SSH et la copie sur chaque worker,
# pour que le master puisse ensuite copier et exécuter des scripts sans mot de passe.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory

KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f "$KEY" ]]; then
  info "Génération de la clé SSH $KEY"
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "master-$(hostname)"
fi

for w in $WORKERS; do
  info "Copie de la clé publique vers $SSH_USER@$w (mot de passe demandé une seule fois)"
  ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=accept-new "$SSH_USER@$w"
done

for w in $WORKERS; do
  if ssh -o BatchMode=yes "$SSH_USER@$w" true 2>/dev/null; then
    ok "SSH sans mot de passe vers $w"
  else
    die "Échec SSH vers $w"
  fi
done
