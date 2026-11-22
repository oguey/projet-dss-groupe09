-- =====================================================================
-- Groupe 09 · 00b · Droits que seul SYS peut donner (à exécuter après 00)
-- Depuis le terminal :
--   docker exec -it oracle-bdd sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba
--   SQL> @/scripts/groupe_09/00b_droits_sys.sql
-- =====================================================================
GRANT EXECUTE ON DBMS_RLS    TO cine09;   -- sécurité par ligne (VPD), L5
GRANT EXECUTE ON DBMS_REDACT TO cine09;   -- masquage des données, L5
GRANT AUDIT_ADMIN            TO cine09;   -- audit unifié, L5
exit
