-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- 04 · L3 · Normalisation (connexion CINE09)
-- 1. Construit le fichier des opérations « à plat » (billet + spectateur
--    + séance + site), tel qu'on le recevrait d'un export unique.
-- 2. Vérifie sur les données chaque dépendance fonctionnelle (DF) :
--    une DF X -> Y est respectée si aucun X n'a plusieurs Y.
-- 3. Mesure la redondance qui justifie la décomposition.
-- 4. Dénormalisation assumée : places confirmées stockées dans SEANCE.
-- Rejouable.
-- =====================================================================

BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'BILLET_A_PLAT') LOOP
    EXECUTE IMMEDIATE 'DROP TABLE billet_a_plat PURGE';
  END LOOP;
END;
/

-- ---------------------------------------------- 1. La relation « à plat »
-- Une ligne par billet dont la séance existe (les 301 billets orphelins
-- n'ont ni séance ni site : ils sont traités au volet 2).
CREATE TABLE billet_a_plat AS
SELECT b.id_billet, b.date_billet, b.nb_places, b.montant, b.statut, b.id_groupe,
       sp.id_spectateur, sp.nom, sp.prenom, sp.email, sp.telephone,
       sp.ville          AS ville_spectateur,
       sp.id_cinema      AS id_cinema_rattachement,
       sp.date_inscription,
       se.id_seance, se.libelle, se.categorie, se.debut, se.duree_minutes,
       se.capacite, se.prix_unitaire,
       se.id_cinema      AS id_cinema_seance,
       c.nom             AS nom_cinema,
       c.ville           AS ville_cinema
FROM   stg_billets b
JOIN   stg_spectateurs sp ON sp.id_spectateur = b.id_spectateur
JOIN   stg_seances     se ON se.id_seance     = b.id_seance
JOIN   stg_cinemas     c  ON c.id_cinema      = se.id_cinema;

SELECT COUNT(*) AS nb_lignes, 24 AS nb_colonnes FROM billet_a_plat;

-- ---------------------------------- 2. Vérification des dépendances
-- Chaque ligne : la DF testée et le nombre de valeurs de gauche qui la
-- violent (0 = la DF est respectée par les données).
SELECT 'DF1 id_billet -> tous les attributs' AS dependance,
       COUNT(*) - COUNT(DISTINCT id_billet) AS violations FROM billet_a_plat
UNION ALL
SELECT 'DF2 id_spectateur -> nom, prenom, email, telephone, ville, rattachement, inscription',
       COUNT(*) FROM (SELECT id_spectateur FROM billet_a_plat GROUP BY id_spectateur
                      HAVING COUNT(DISTINCT nom || '|' || prenom || '|' || email || '|' || telephone
                                   || '|' || ville_spectateur || '|' || id_cinema_rattachement
                                   || '|' || TO_CHAR(date_inscription, 'YYYYMMDD')) > 1)
UNION ALL
SELECT 'DF3 id_seance -> libelle, categorie, debut, duree, capacite, prix, site',
       COUNT(*) FROM (SELECT id_seance FROM billet_a_plat GROUP BY id_seance
                      HAVING COUNT(DISTINCT libelle || '|' || categorie || '|' || TO_CHAR(debut, 'YYYYMMDDHH24MI')
                                   || '|' || duree_minutes || '|' || capacite || '|' || prix_unitaire
                                   || '|' || id_cinema_seance) > 1)
UNION ALL
SELECT 'DF4 id_cinema_seance -> nom_cinema, ville_cinema',
       COUNT(*) FROM (SELECT id_cinema_seance FROM billet_a_plat GROUP BY id_cinema_seance
                      HAVING COUNT(DISTINCT nom_cinema || '|' || ville_cinema) > 1)
UNION ALL
SELECT 'DF5 ville_spectateur -> id_cinema_rattachement',
       COUNT(*) FROM (SELECT ville_spectateur FROM billet_a_plat GROUP BY ville_spectateur
                      HAVING COUNT(DISTINCT id_cinema_rattachement) > 1)
UNION ALL
SELECT 'DF6 (nb_places, prix_unitaire) -> montant',
       COUNT(*) FROM (SELECT nb_places, prix_unitaire FROM billet_a_plat GROUP BY nb_places, prix_unitaire
                      HAVING COUNT(DISTINCT montant) > 1)
UNION ALL
SELECT 'NON-DF id_groupe -> id_spectateur (payeur)',
       COUNT(*) FROM (SELECT id_groupe FROM billet_a_plat WHERE id_groupe IS NOT NULL GROUP BY id_groupe
                      HAVING COUNT(DISTINCT id_spectateur) > 1)
UNION ALL
SELECT 'NON-DF id_groupe -> date_billet',
       COUNT(*) FROM (SELECT id_groupe FROM billet_a_plat WHERE id_groupe IS NOT NULL GROUP BY id_groupe
                      HAVING COUNT(DISTINCT date_billet) > 1)
UNION ALL
SELECT 'NON-DF lower(email) -> id_spectateur (doublons de personnes)',
       COUNT(*) FROM (SELECT LOWER(TRIM(email)) FROM stg_spectateurs WHERE email IS NOT NULL
                      GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1);

-- ------------------------------------------- 3. Mesure de la redondance
-- Combien de fois chaque fait est répété dans la relation à plat :
-- c'est le coût (place et anomalies de mise à jour) que la 3NF supprime.
SELECT 'spectateur' AS fait, COUNT(*) AS lignes_a_plat,
       COUNT(DISTINCT id_spectateur) AS valeurs_distinctes,
       ROUND(COUNT(*) / COUNT(DISTINCT id_spectateur), 1) AS repetitions_moyennes
FROM billet_a_plat
UNION ALL
SELECT 'seance', COUNT(*), COUNT(DISTINCT id_seance),
       ROUND(COUNT(*) / COUNT(DISTINCT id_seance), 1) FROM billet_a_plat
UNION ALL
SELECT 'site (cinema)', COUNT(*), COUNT(DISTINCT id_cinema_seance),
       ROUND(COUNT(*) / COUNT(DISTINCT id_cinema_seance), 1) FROM billet_a_plat;

-- Taille de la relation à plat (Mo) ; à comparer au volet 2 avec les
-- tables décomposées une fois chargées.
SELECT segment_name, ROUND(bytes / 1024 / 1024, 1) AS taille_mo, blocks
FROM   user_segments
WHERE  segment_name = 'BILLET_A_PLAT';

-- ------------------------------------ 4. Dénormalisation assumée (ADR-01)
-- SEANCE.places_confirmees = somme des places des billets confirmés.
-- Valeur calculable (donc redondante), stockée pour contrôler la capacité
-- (RG10) sans additionner les billets à chaque vente, au moment du pic des
-- avant-premières. Calculée au chargement (volet 2), maintenue par
-- trigger (volet 3), contrôlée par une requête de cohérence.
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM user_tab_columns
  WHERE  table_name = 'SEANCE' AND column_name = 'PLACES_CONFIRMEES';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE seance ADD (places_confirmees NUMBER(6) DEFAULT 0 '
                   || 'CONSTRAINT nn_seance_places_conf NOT NULL '
                   || 'CONSTRAINT ck_seance_places_conf CHECK (places_confirmees >= 0))';
  END IF;
END;
/

SELECT column_name, data_type, data_default
FROM   user_tab_columns
WHERE  table_name = 'SEANCE' AND column_name = 'PLACES_CONFIRMEES';
