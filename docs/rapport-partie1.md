# Rapport, Partie 1 : service de déploiement de WordPress sur Kubernetes

**Étudiant :** Radoslav Stoilov · **Groupe :** 00002
**Cours :** Serveurs de réseaux locaux 3 (420H64RO), Hiver 2026 · **Enseignant :** Djibo Karimou
**Date :** ____________

---

## 1. Objectif

Une petite structure veut publier son site WordPress sur un cluster Kubernetes. Le service doit être accessible depuis l'extérieur du cluster, conserver ses données lorsqu'un conteneur est recréé, et se redéployer de façon fiable. Le master doit pouvoir copier et exécuter des scripts sur les workers.

## 2. Environnement

| Nœud | Rôle | Adresse IP | Système | Ressources |
|---|---|---|---|---|
| master | Plan de contrôle et serveur NFS | 192.168.1.10 | Ubuntu ___ | __ vCPU / __ Go |
| worker1 | Nœud de travail | 192.168.1.11 | Ubuntu ___ | __ vCPU / __ Go |
| worker2 | Nœud de travail | 192.168.1.12 | Ubuntu ___ | __ vCPU / __ Go |

Kubernetes ______ (kubeadm), runtime containerd, CNI ______ (Calico / Flannel).

## 3. Schéma d'architecture

*(Insérer le diagramme du README, rendu par GitHub, ou une version redessinée.)*

Flux : poste extérieur → `http://wordpress.local:30080` → Service NodePort (présent sur chaque nœud) → pod(s) WordPress → Service `mysql` (ClusterIP, interne) → pod MySQL → volume persistant NFS sur le master.

## 4. Justification des choix

**Stockage : NFS avec des PV statiques.** Un cluster kubeadm n'a pas de StorageClass par défaut. Avec `hostPath`, les données resteraient sur un seul worker : si le pod MySQL était recréé ailleurs, il démarrerait avec une base vide. NFS rend les données accessibles depuis n'importe quel nœud. La politique `Retain` garantit que supprimer l'application ne détruit pas les données. Elles ne sont effacées que sur demande explicite (`destroy.sh --purge`).

**Exposition : NodePort 30080.** C'est la solution la plus simple qui fonctionne sans composant supplémentaire sur un cluster nu. Le site répond sur l'adresse de chaque nœud. Alternatives écartées : `LoadBalancer`, qui exige MetalLB sur site, et `Ingress`, qui exige un contrôleur et un DNS (prévus en perspective). La base n'est **pas** exposée : son service est de type ClusterIP.

**Secrets.** Les identifiants sont dans un fichier `.env` local, exclu par `.gitignore`. `deploy.sh` les transforme en Secret Kubernetes (`kubectl create secret --from-env-file`). Aucun manifeste ne contient de mot de passe : les pods les lisent via `secretKeyRef`.

**MySQL en Deployment `Recreate`.** Une seule instance écrit dans le dossier de données. `Recreate` arrête l'ancien pod avant de démarrer le nouveau, ce qui évite la corruption de la base.

**Scripts distants.** Une clé SSH ed25519 est copiée une fois sur chaque worker (`ssh-setup.sh`). Ensuite, `run-on-workers.sh` copie un script (`scp`), l'exécute (`ssh`) et affiche la sortie de chaque worker sur le master. Ce mécanisme sert aussi à installer le client NFS sur les workers.

**Procédure rejouable.** `deploy.sh` est idempotent : `kubectl apply` et `create secret --dry-run | apply` peuvent être relancés sans erreur. `destroy.sh` suivi de `deploy.sh` redonne un site fonctionnel.

## 5. Procédure

Voir le README, section 4. En résumé : `ssh-setup.sh` → `run-on-workers.sh` → `setup-nfs-server.sh` → `deploy.sh`.

## 6. Preuves des tests

Les sorties datées sont générées par `./tests/run-tests.sh` dans `preuves/<date>/`.

| N° | Test | Résultat attendu | Résultat obtenu | Preuve |
|---|---|---|---|---|
| 1 | Lister les nœuds du cluster | 3 nœuds Ready | | test-1.txt + capture |
| 2 | Script du master sur chaque worker | Sortie de chaque worker sur le master | | test-2.txt |
| 3 | Volumes persistants | PVC Bound | | test-3.txt |
| 4 | Contenu créé, pod de la base supprimé puis recréé | Contenu toujours présent | | test-4.txt + captures avant/après |
| 5 | Site ouvert depuis un poste extérieur | Page affichée, adresse visible | | capture navigateur |
| 6 | Mots de passe en clair dans le dépôt et l'historique | Aucun mot de passe réel trouvé | | test-6.txt |
| 7 | Pod WordPress supprimé | Nouveau pod créé, site de retour | | test-7.txt |
| 8 | Repartir de zéro puis rejouer | Site de nouveau opérationnel | | test-8.txt |

*(Coller ici chaque capture ou extrait de sortie, avec sa date visible.)*

## 7. Difficultés rencontrées et solutions

| Difficulté | Cause | Solution |
|---|---|---|
| *ex. PVC restées en Pending* | *PV « Released » après une suppression* | *destroy.sh supprime aussi les PV, deploy.sh les recrée* |
| *ex. Pod bloqué en ContainerCreating* | *client NFS absent sur un worker* | *installation via run-on-workers.sh --sudo* |
| | | |

## 8. Conclusion

Le service répond au cahier des charges : cluster de 3 nœuds, scripts exécutés à distance depuis le master, persistance démontrée, accès externe, secrets hors du dépôt et procédure rejouable. Ses limites (installation manuelle, un seul environnement, aucune surveillance, aucune sauvegarde) sont analysées et traitées dans la partie 2.
