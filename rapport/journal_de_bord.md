# Journal de bord — Groupe 09

## 20/11/2026
**Ce qui s'est fait :**
- Réception du sujet et des CSV. Analyse rapide : plein de défauts dedans (doublons e-mail, e-mails vides, billets inexistants, montants négatifs, etc.)
- Décision : laisser les données brutes pour C1-C9, pas de nettoyage
- Installation de Docker + Oracle 26ai Free + SQL Developer
- Création utilisateur CINE09

**Problèmes rencontrés :**
- ALTER SESSION SET CONTAINER avec reconnexion pop-up → supprimé du script
- Droits insuffisants pour DBMS_RLS et DBMS_REDACT en SYSTEM → créé script 00b en SYSDBA

## 22/11/2026
**Ce qui s'est fait :**
- CSV chargés en tables externes (script 01) : OK
- C1-C9 calculés (script 02)
- Format de date fixé à DD/MM/YYYY pour C4

**Problèmes rencontrés :**
- Oups, j'ai tapé la commande docker dans sqlplus au lieu du terminal
- CSV introuvables → les chercher dans le bon dossier
- Captures A1-A9 faites

## 23/11/2026
**Ce qui s'est fait :**
- Script 03 : 10 tables du modèle créées (OK)
- Schéma entité-association avec Mocodo
- Script 04 : vérification des dépendances
- Script 05 : chargement avec fusion/validation
- Script 06 : requêtes R4-R6

**Problèmes rencontrés :**
- R4 (division par double NOT EXISTS) bloque SQL Developer → réécrite avec comptage, 0,5s au lieu de bloquer
- Captures à refaire plusieurs fois (output pas vidé, mauvais onglet)
