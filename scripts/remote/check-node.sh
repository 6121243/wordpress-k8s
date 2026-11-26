#!/usr/bin/env bash
# Script exécuté SUR chaque worker (copié par run-on-workers.sh).
# Affiche un état de santé du nœud.
echo "Nœud       : $(hostname)"
echo "Adresse IP : $(hostname -I | awk '{print $1}')"
echo "Date       : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Système    : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Uptime     : $(uptime -p)"
echo "kubelet    : $(systemctl is-active kubelet 2>/dev/null || echo inconnu)"
echo "containerd : $(systemctl is-active containerd 2>/dev/null || echo inconnu)"
echo "Client NFS : $(command -v mount.nfs >/dev/null && echo installé || echo ABSENT)"
echo "Disque /   : $(df -h / | awk 'NR==2 {print $3" utilisés / "$2" ("$5")"}')"
echo "Mémoire    : $(free -h | awk '/^Mem/ {print $3" / "$2}')"
