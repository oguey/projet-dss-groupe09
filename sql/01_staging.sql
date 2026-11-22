-- =====================================================================
-- Groupe 09 · 01 · Chargement BRUT des CSV (connexion CINE09)
-- Tables externes sur /scripts/groupe_09, puis copie dans des tables
-- STG_* sans contrainte métier : elles gardent les lignes défectueuses
-- telles quelles (les valeurs de contrôle C1 à C9 portent sur les fichiers).
-- Rejouable.
-- =====================================================================
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('EXT_CINEMAS','EXT_SPECTATEURS','EXT_SEANCES','EXT_BILLETS',
                                 'STG_CINEMAS','STG_SPECTATEURS','STG_SEANCES','STG_BILLETS')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
  END LOOP;
END;
/

-- ---------- Tables externes (tout en texte : aucun rejet au chargement)
CREATE TABLE ext_cinemas (
  id_cinema VARCHAR2(20), nom VARCHAR2(100), ville VARCHAR2(100), role VARCHAR2(50)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY dir_cine09
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE CHARACTERSET AL32UTF8 SKIP 1
    NOBADFILE NOLOGFILE NODISCARDFILE
    FIELDS TERMINATED BY ',' NOTRIM MISSING FIELD VALUES ARE NULL)
  LOCATION ('cinemas.csv'))
REJECT LIMIT UNLIMITED;

CREATE TABLE ext_spectateurs (
  id_spectateur VARCHAR2(20), nom VARCHAR2(100), prenom VARCHAR2(100), email VARCHAR2(200),
  telephone VARCHAR2(30), ville VARCHAR2(100), id_cinema VARCHAR2(20), date_inscription VARCHAR2(30)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY dir_cine09
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE CHARACTERSET AL32UTF8 SKIP 1
    NOBADFILE NOLOGFILE NODISCARDFILE
    FIELDS TERMINATED BY ',' NOTRIM MISSING FIELD VALUES ARE NULL)
  LOCATION ('spectateurs.csv'))
REJECT LIMIT UNLIMITED;

CREATE TABLE ext_seances (
  id_seance VARCHAR2(20), libelle VARCHAR2(200), categorie VARCHAR2(50), id_cinema VARCHAR2(20),
  debut VARCHAR2(30), duree_minutes VARCHAR2(20), capacite VARCHAR2(20), prix_unitaire VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY dir_cine09
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE CHARACTERSET AL32UTF8 SKIP 1
    NOBADFILE NOLOGFILE NODISCARDFILE
    FIELDS TERMINATED BY ',' NOTRIM MISSING FIELD VALUES ARE NULL)
  LOCATION ('seances.csv'))
REJECT LIMIT UNLIMITED;

CREATE TABLE ext_billets (
  id_billet VARCHAR2(20), id_spectateur VARCHAR2(20), id_seance VARCHAR2(20), date_billet VARCHAR2(30),
  nb_places VARCHAR2(20), montant VARCHAR2(20), statut VARCHAR2(30), id_groupe VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY dir_cine09
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE CHARACTERSET AL32UTF8 SKIP 1
    NOBADFILE NOLOGFILE NODISCARDFILE
    FIELDS TERMINATED BY ',' NOTRIM MISSING FIELD VALUES ARE NULL)
  LOCATION ('billets.csv'))
REJECT LIMIT UNLIMITED;

-- ---------- Tables de chargement typées (copie fidèle des fichiers)
-- L'email est gardé tel quel (espaces compris) : le nettoyage se fait plus tard.
CREATE TABLE stg_cinemas AS
SELECT TO_NUMBER(id_cinema) AS id_cinema, nom, ville, role FROM ext_cinemas;

CREATE TABLE stg_spectateurs AS
SELECT TO_NUMBER(id_spectateur)            AS id_spectateur,
       nom, prenom, email, telephone, ville,
       TO_NUMBER(id_cinema)                AS id_cinema,
       TO_DATE(date_inscription, 'YYYY-MM-DD') AS date_inscription
FROM   ext_spectateurs;

CREATE TABLE stg_seances AS
SELECT TO_NUMBER(id_seance)                          AS id_seance,
       libelle, categorie,
       TO_NUMBER(id_cinema)                          AS id_cinema,
       TO_DATE(debut, 'YYYY-MM-DD HH24:MI:SS')       AS debut,
       TO_NUMBER(duree_minutes)                      AS duree_minutes,
       TO_NUMBER(capacite)                           AS capacite,
       TO_NUMBER(prix_unitaire)                      AS prix_unitaire
FROM   ext_seances;

CREATE TABLE stg_billets AS
SELECT TO_NUMBER(id_billet)                          AS id_billet,
       TO_NUMBER(id_spectateur)                      AS id_spectateur,
       TO_NUMBER(id_seance)                          AS id_seance,
       TO_DATE(date_billet, 'YYYY-MM-DD HH24:MI:SS') AS date_billet,
       TO_NUMBER(nb_places)                          AS nb_places,
       TO_NUMBER(montant)                            AS montant,
       statut,
       id_groupe
FROM   ext_billets;

-- ---------- Contrôle du chargement : doit donner 4 / 20820 / 7519 / 378708
SELECT 'stg_cinemas' AS table_chargee, COUNT(*) AS nb_lignes FROM stg_cinemas
UNION ALL SELECT 'stg_spectateurs', COUNT(*) FROM stg_spectateurs
UNION ALL SELECT 'stg_seances',     COUNT(*) FROM stg_seances
UNION ALL SELECT 'stg_billets',     COUNT(*) FROM stg_billets;
