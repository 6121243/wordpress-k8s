#!/usr/bin/env bash
# Script exécuté SUR chaque worker (avec sudo) : installe le client NFS,
# nécessaire au kubelet pour monter les volumes persistants NFS.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if command -v mount.nfs >/dev/null; then
  echo "$(hostname) : client NFS déjà installé"
else
  apt-get update -qq
  apt-get install -y -qq nfs-common
  echo "$(hostname) : client NFS installé"
fi
