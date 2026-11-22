-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- 00 · Création du compte du projet CINE09 (à exécuter en SYSTEM,
--      connexion BDD-system, PDB FREEPDB1). Rejouable : supprime
--      l'utilisateur s'il existe déjà.
-- Prérequis : les 4 CSV sont dans C:\bdd-kit\1-oracle-mysql\scripts\groupe_09
--             (visible dans le conteneur sous /scripts/groupe_09).
-- =====================================================================
-- La connexion BDD-system est déjà sur FREEPDB1 : pas de ALTER SESSION SET CONTAINER
-- (SQL Developer réinitialise la session si on change de conteneur).

BEGIN
  FOR u IN (SELECT username FROM dba_users WHERE username = 'CINE09') LOOP
    EXECUTE IMMEDIATE 'DROP USER cine09 CASCADE';
  END LOOP;
END;
/

CREATE USER cine09 IDENTIFIED BY "cine09"
    DEFAULT TABLESPACE USERS
    QUOTA UNLIMITED ON USERS;

-- Droits de base (identiques au compte club du kit)
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE,
      CREATE TRIGGER, CREATE TYPE, CREATE SYNONYM, CREATE MATERIALIZED VIEW,
      CREATE DATABASE LINK TO cine09;
GRANT SELECT_CATALOG_ROLE TO cine09;

-- Lecture des CSV par tables externes (dossier partagé du kit, lecture seule)
CREATE OR REPLACE DIRECTORY dir_cine09 AS '/scripts/groupe_09';
GRANT READ ON DIRECTORY dir_cine09 TO cine09;

-- Pour L5 (sécurité) : rôles et comptes de test
-- (les droits sur DBMS_RLS et DBMS_REDACT ne peuvent être donnés que par SYS :
--  voir 00b_droits_sys.sql ; erreur obtenue en SYSTEM : ORA-01031)
GRANT CREATE ROLE, CREATE USER TO cine09;

-- Vérification
SELECT username, account_status, default_tablespace
FROM   dba_users WHERE username = 'CINE09';
