# Projet Data Storage Systems — Groupe 09 · Cinéma indépendant (Nancy, Metz, Reims)

Plateforme de données d'un cinéma indépendant multi-sites : un siège (Paris) et trois sites.
Opération groupée multi-sites : carte d'abonnement et séances spéciales communes.
Pic de trafic : avant-premières.

## Prérequis

1. Kit du cours `bdd-kit` installé (Oracle AI Database 26ai Free, service `FREEPDB1`), Oracle démarré :
   ```
   cd bdd-kit\1-oracle-mysql
   docker compose up -d oracle
   ```
2. **Copier les 4 CSV** de `donnees_groupe_09.zip` (cinemas, spectateurs, seances, billets) dans
   `bdd-kit\1-oracle-mysql\scripts\groupe_09\` : Oracle les lit dans le conteneur sous `/scripts/groupe_09`.
   Les CSV ne sont jamais modifiés ; ils ne sont pas versionnés dans ce dépôt.
3. Copier aussi `sql\00b_droits_sys.sql` dans ce même dossier (il est exécuté depuis sqlplus).

## Ordre d'exécution des scripts

| # | Script | Connexion | Rôle | Livrable |
|---|---|---|---|---|
| 00 | `sql/00_utilisateur.sql` | system / oracle (FREEPDB1) | crée l'utilisateur CINE09 et le répertoire des CSV | — |
| 00b | `sql/00b_droits_sys.sql` | sys as sysdba (voir ci-dessous) | droits que seul SYS peut donner (DBMS_RLS, DBMS_REDACT, AUDIT_ADMIN) | — |
| 01 | `sql/01_staging.sql` | cine09 / cine09 | chargement brut des CSV (tables externes → tables STG_*) | L2 |
| 02 | `sql/02_controle_C1_C9.sql` | cine09 / cine09 | valeurs de contrôle C1 à C9, calculées sur les fichiers | L2 |
| 03 | `sql/03_creation_modele.sql` | cine09 / cine09 | 10 tables du modèle, contraintes nommées, CINEMA et CATEGORIE | L1 |
| 04 | `sql/04_normalisation_L3.sql` | cine09 / cine09 | table à plat, vérification des DF, dénormalisation `places_confirmees` | L3 |
| 05 | `sql/05_chargement_L2.sql` | cine09 / cine09 | chargement propre, défauts tracés dans JOURNAL_CHARGEMENT | L2 |
| 06 | `sql/06_requetes_metier_L2.sql` | cine09 / cine09 | 10 requêtes métier | L2 |

Tous les scripts s'exécutent en entier (F5 dans SQL Developer) et sont rejouables.

Commande pour 00b :
```
docker exec -it oracle-bdd sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba
SQL> @/scripts/groupe_09/00b_droits_sys.sql
```

Résultats attendus : voir `rapport/` (C1 à C9 en tête de L2, comptages de chargement, résultats des requêtes).

## Organisation du dépôt

```
sql/        scripts Oracle, numérotés dans l'ordre d'exécution
nosql/      scripts MongoDB, Redis… (L6, L7)
captures/   captures d'écran de l'annexe (A1, A2…)
rapport/    textes des livrables, ADR, journal de bord, déclaration d'usage de l'IA
  modele/   source Mocodo du schéma entité-association
donnees/    emplacement prévu des CSV (non versionnés)
```

## Avancement

- [x] Volet 0 · chargement brut et valeurs de contrôle C1 à C9 (captures A1 à A9)
- [x] Volet 1 · L1 modèle + L3 normalisation (captures A10 à A14), ADR-01 premier jet
- [x] Volet 2 · L2 chargement propre et 10 requêtes métier (captures A15 à A28)
- [ ] Volet 3 · L4 fiabilité : triggers, journal d'audit, package de vente groupée, concurrence
- [ ] Volet 4 · L5 performance et sécurité
- [ ] Volet 5 · L6 distribution
- [ ] Volet 6 · L7 NoSQL
- [ ] Volet 7 · L8 ADR et rapport
