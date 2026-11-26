#!/usr/bin/env bash
# Exécute les tests du cahier des charges et enregistre une preuve datée
# de chacun dans preuves/AAAAMMJJ-HHMMSS/test-N.txt
#
# Usage : ./tests/run-tests.sh            -> tous les tests
#         ./tests/run-tests.sh 3 7        -> seulement les tests 3 et 7
set -uo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
load_inventory
cd "$ROOT_DIR"

OUT="$ROOT_DIR/preuves/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
URL="http://$MASTER_IP:$NODE_PORT"
K="kubectl -n $NAMESPACE"

header() { echo "=== Test $1 : $2"; echo "=== $(date '+%Y-%m-%d %H:%M:%S %Z') — $(whoami)@$(hostname)"; echo; }
http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL/" || true; }
wait_http() { for _ in $(seq 1 60); do c=$(http_code); [[ "$c" =~ ^(200|301|302)$ ]] && { echo "HTTP $c sur $URL"; return 0; }; sleep 5; done; echo "Site injoignable"; return 1; }
mysql_q() { $K exec deploy/mysql -- sh -c "mysql -N -u\"\$MYSQL_USER\" -p\"\$MYSQL_PASSWORD\" \"\$MYSQL_DATABASE\" -e \"$1\"" 2>/dev/null; }

t1() { header 1 "Lister les nœuds du cluster"
  kubectl get nodes -o wide; }

t2() { header 2 "Exécuter un script du master sur chaque worker"
  ./scripts/run-on-workers.sh scripts/remote/check-node.sh; }

t3() { header 3 "Vérifier les volumes persistants"
  kubectl get pv -l app.kubernetes.io/part-of=wordpress-k8s; echo; $K get pvc; }

t4() { header 4 "Persistance : contenu conservé après recréation du pod MySQL"
  echo "Dans WordPress (wp-admin), publiez un article intitulé : Test persistance"
  read -r -p "Appuyez sur Entrée quand c'est fait... " _ </dev/tty
  echo "--- AVANT suppression :"; mysql_q "SELECT ID, post_title, post_date FROM wp_posts WHERE post_title LIKE 'Test persistance%' AND post_status='publish';"
  OLD=$($K get pod -l app=mysql -o name); echo "Pod actuel : $OLD"
  $K delete "$OLD" --wait=true
  sleep 5
  $K rollout status deployment/mysql --timeout=300s
  $K wait --for=condition=Ready pod -l app=mysql --timeout=300s
  for _ in $(seq 1 40); do mysql_q "SELECT 1;" >/dev/null && break; sleep 3; done
  echo "Nouveau pod : $($K get pod -l app=mysql -o name)"
  echo "--- APRÈS recréation :"; mysql_q "SELECT ID, post_title, post_date FROM wp_posts WHERE post_title LIKE 'Test persistance%' AND post_status='publish';"
  wait_http; }

t5() { header 5 "Accès depuis l'extérieur du cluster"
  for ip in $MASTER_IP $WORKERS; do
    echo "http://$ip:$NODE_PORT -> HTTP $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$ip:$NODE_PORT/")"
  done
  echo; echo "+ Capture d'écran du navigateur du poste extérieur (adresse visible) : http://$SITE_NAME:$NODE_PORT"; }

t6() { header 6 "Recherche de mots de passe en clair (dépôt + historique)"
  ./tests/check-secrets.sh; }

t7() { header 7 "Suppression du pod WordPress -> recréation automatique"
  $K get pods -l app=wordpress -o wide
  OLD=$($K get pod -l app=wordpress -o name | head -1); echo "Suppression de $OLD"
  $K delete "$OLD" --wait=false
  sleep 3; $K get pods -l app=wordpress -o wide
  $K rollout status deployment/wordpress --timeout=300s
  $K get pods -l app=wordpress -o wide
  wait_http; }

t8() { header 8 "Repartir de zéro puis rejouer la procédure"
  ./scripts/destroy.sh
  kubectl get ns "$NAMESPACE" 2>&1 || true
  echo "Site après suppression : HTTP $(http_code)"
  ./scripts/deploy.sh "${DEPLOY_TARGET:-base}"
  wait_http; }

TESTS=("$@"); [[ ${#TESTS[@]} -eq 0 ]] && TESTS=(1 2 3 4 5 6 7 8)
for n in "${TESTS[@]}"; do
  declare -F "t$n" >/dev/null || { warn "Test $n inconnu"; continue; }
  "t$n" 2>&1 | tee "$OUT/test-$n.txt"
  echo
done
ok "Preuves enregistrées dans $OUT"
