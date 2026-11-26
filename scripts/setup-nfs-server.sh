#!/usr/bin/env bash
# À lancer sur le master (serveur NFS) : sudo ./scripts/setup-nfs-server.sh
# Crée les dossiers de données et les exporte vers le réseau du cluster.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory
[[ $EUID -eq 0 ]] || die "À lancer avec sudo"

export DEBIAN_FRONTEND=noninteractive
info "Installation de nfs-kernel-server"
apt-get update -qq && apt-get install -y -qq nfs-kernel-server

mkdir -p "$NFS_PATH"/{mysql,wp-content,backups}
chmod 755 "$NFS_PATH"

# no_root_squash : les entrypoints MySQL/WordPress (root) doivent pouvoir faire chown
LINE="$NFS_PATH $NFS_ALLOWED_NET(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -qF "$NFS_PATH " /etc/exports; then
  echo "$LINE" >> /etc/exports
fi
exportfs -ra
systemctl enable --now nfs-kernel-server
ok "Export NFS actif :"
exportfs -v
