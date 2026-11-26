#!/usr/bin/env bash
# Test 6 : recherche de mots de passe en clair dans le dépôt ET tout son historique.
# 1) cherche les VRAIES valeurs de .env dans chaque commit de chaque branche
# 2) lance gitleaks s'il est installé
set -uo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
cd "$ROOT_DIR"
load_env

git rev-parse --git-dir >/dev/null 2>&1 || die "Pas un dépôt Git"
REVS=$(git rev-list --all)
[[ -n "$REVS" ]] || die "Aucun commit à analyser"
echo "Commits analysés : $(echo "$REVS" | wc -l) (toutes branches)"

FOUND=0
for var in MYSQL_PASSWORD MYSQL_ROOT_PASSWORD; do
  # shellcheck disable=SC2086
  if git grep -lF -- "${!var}" $REVS >/dev/null 2>&1; then
    warn "La valeur de $var apparaît dans l'historique !"; FOUND=1
  else
    ok "Valeur de $var : absente de tout l'historique"
  fi
done

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  warn ".env est suivi par Git !"; FOUND=1
else
  ok ".env n'est pas suivi par Git"
fi

if command -v gitleaks >/dev/null; then
  info "Analyse gitleaks de tout l'historique"
  gitleaks detect --source . --log-opts="--all" -v || FOUND=1
else
  warn "gitleaks non installé (analyse faite aussi dans la CI GitHub Actions)"
fi

if [[ $FOUND -eq 0 ]]; then ok "RÉSULTAT : aucun mot de passe réel trouvé"; else die "RÉSULTAT : secret détecté"; fi
