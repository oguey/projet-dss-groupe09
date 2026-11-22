# Projet Data Storage Systems — Groupe 09 · Cinéma indépendant (Nancy, Metz, Reims)

Plateforme de données d'un cinéma indépendant multi-sites : un siège (Paris) et trois sites.
Opération groupée multi-sites : carte d'abonnement et séances spéciales communes.
Pic de trafic : avant-premières.

## Prérequis

Kit du cours `bdd-kit` installé (Oracle AI Database 26ai Free, service `FREEPDB1`).

```
cd bdd-kit\1-oracle-mysql
docker compose up -d oracle
```

**Copier les 4 CSV** de `donnees_groupe_09.zip` dans `bdd-kit\1-oracle-mysql\scripts\groupe_09\`
(dossier visible dans le conteneur sous `/scripts/groupe_09`).

## Ordre d'exécution des scripts

| # | Script | Connexion | Rôle |
|---|---|---|---|
| 00 | `sql/00_utilisateur.sql` | system / oracle (FREEPDB1) | crée l'utilisateur CINE09 et le répertoire des CSV |
| 00b | `sql/00b_droits_sys.sql` | sys as sysdba (FREEPDB1) | droits que seul SYS peut donner (DBMS_RLS, DBMS_REDACT, AUDIT_ADMIN) |
| 01 | `sql/01_staging.sql` | cine09 / cine09 | chargement brut des CSV (tables externes → STG_*) |
| 02 | `sql/02_controle_C1_C9.sql` | cine09 / cine09 | valeurs de contrôle C1 à C9 |

Commande pour 00b :
```
docker exec -it oracle-bdd sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba
SQL> @/scripts/groupe_09/00b_droits_sys.sql
```
(copier aussi `00b_droits_sys.sql` dans `scripts\groupe_09`.)

## Organisation du dépôt

```
sql/        scripts Oracle, numérotés dans l'ordre d'exécution
nosql/      scripts MongoDB, Redis… (L6, L7)
captures/   captures d'écran de l'annexe (A1, A2…)
rapport/    rapport, ADR, journal de bord, déclaration d'usage de l'IA
donnees/    emplacement des CSV (non versionnés)
```

## Avancement

- [x] Volet 0 · chargement brut et valeurs de contrôle C1 à C9
- [ ] Volet 1 · L1 modèle + L3 normalisation
- [ ] Volet 2 · L2 chargement propre et requêtes métier
- [ ] Volet 3 · L4 fiabilité
- [ ] Volet 4 · L5 performance et sécurité
- [ ] Volet 5 · L6 distribution
- [ ] Volet 6 · L7 NoSQL
- [ ] Volet 7 · L8 ADR et rapport
