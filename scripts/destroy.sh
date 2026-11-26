#!/usr/bin/env bash
# Supprime l'application (namespace + PV).
# Usage : ./scripts/destroy.sh           -> les données NFS sont CONSERVÉES
#         ./scripts/destroy.sh --purge   -> les données NFS sont EFFACÉES (vrai départ de zéro)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory

info "Suppression du namespace $NAMESPACE (pods, services, PVC, secret)"
kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=true

info "Suppression des PersistentVolumes"
kubectl delete pv -l app.kubernetes.io/part-of=wordpress-k8s --ignore-not-found

if [[ "${1:-}" == "--purge" ]]; then
  read -r -p "Effacer DÉFINITIVEMENT les données de $NFS_PATH ? (oui/non) " ans
  if [[ "$ans" == "oui" ]]; then
    sudo find "$NFS_PATH"/mysql "$NFS_PATH"/wp-content -mindepth 1 -delete
    ok "Données effacées (les sauvegardes dans $NFS_PATH/backups sont conservées)"
  else
    warn "Purge annulée"
  fi
else
  info "Données conservées dans $NFS_PATH (reclaimPolicy: Retain)"
fi
ok "Application supprimée. Pour redéployer : ./scripts/deploy.sh"
