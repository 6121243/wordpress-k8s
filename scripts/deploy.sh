#!/usr/bin/env bash
# Déploiement complet et rejouable (idempotent) de WordPress + MySQL.
# Usage : ./scripts/deploy.sh [base|prod]
#   base : partie 1 (défaut)
#   prod : partie 2 (sondes, répliques, sécurité, sauvegardes)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_inventory
load_env

TARGET="${1:-base}"
case "$TARGET" in
  base) KUSTOMIZE_DIR="$ROOT_DIR/k8s/base" ;;
  prod) KUSTOMIZE_DIR="$ROOT_DIR/k8s/overlays/prod" ;;
  *) die "Cible inconnue : $TARGET (base|prod)" ;;
esac

command -v kubectl >/dev/null || die "kubectl introuvable"
kubectl version >/dev/null 2>&1 || die "Cluster injoignable"

# Le namespace et les PV sont des objets "cluster" : seul un admin peut les créer.
# Le compte CI "deployer" (RBAC limité) saute donc ces étapes.
if [[ "$(kubectl auth can-i create persistentvolumes 2>/dev/null)" == "yes" ]]; then
  info "1/5 Namespace"
  kubectl apply -f "$ROOT_DIR/k8s/base/namespace.yaml"

  info "2/5 Volumes persistants NFS ($NFS_SERVER:$NFS_PATH)"
  sed -e "s|__NFS_SERVER__|$NFS_SERVER|g" -e "s|__NFS_PATH__|$NFS_PATH|g" \
    "$ROOT_DIR/k8s/storage/pv-nfs.tpl.yaml" | kubectl apply -f -
else
  warn "1-2/5 Compte limité (RBAC) : namespace et PV supposés déjà créés par un admin"
fi

info "3/5 Secret (créé depuis .env, jamais stocké dans Git)"
kubectl -n "$NAMESPACE" create secret generic wordpress-db \
  --from-env-file="$ROOT_DIR/.env" \
  --dry-run=client -o yaml | kubectl apply -f -

info "4/5 Application ($TARGET)"
kubectl apply -k "$KUSTOMIZE_DIR"

info "5/5 Attente de la disponibilité"
kubectl -n "$NAMESPACE" rollout status deployment/mysql --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/wordpress --timeout=300s

echo
kubectl -n "$NAMESPACE" get pods,svc,pvc -o wide
echo
ok "WordPress est accessible depuis l'extérieur :"
echo "    http://$MASTER_IP:$NODE_PORT"
for w in $WORKERS; do echo "    http://$w:$NODE_PORT"; done
echo "    http://$SITE_NAME:$NODE_PORT  (après ajout dans /etc/hosts du poste extérieur)"
