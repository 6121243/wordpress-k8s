#!/usr/bin/env bash
# Fonctions communes à tous les scripts.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE=wordpress

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERREUR]\033[0m %s\n' "$*" >&2; exit 1; }

load_inventory() {
  [[ -f "$ROOT_DIR/inventory.conf" ]] || die "inventory.conf introuvable"
  # shellcheck source=/dev/null
  source "$ROOT_DIR/inventory.conf"
  [[ -n "${WORKERS:-}" ]] || die "WORKERS est vide dans inventory.conf"
}

load_env() {
  [[ -f "$ROOT_DIR/.env" ]] || die ".env introuvable : cp .env.example .env puis éditez-le"
  set -a
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
  set +a
  local v
  for v in MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD; do
    [[ -n "${!v:-}" ]] || die "$v manquant dans .env"
    [[ "${!v}" != "A_REMPLACER" ]] || die "$v vaut encore A_REMPLACER dans .env"
  done
}
