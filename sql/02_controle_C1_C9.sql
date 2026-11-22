-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- Valeurs de contrôle C1 à C9 (Oracle)
-- Calculées sur les tables de chargement BRUTES (STG_*), c.-à-d. sur
-- les CSV tels quels, avant tout nettoyage : les définitions du sujet
-- portent sur « vos fichiers ».
-- Prérequis : 01_staging.sql exécuté et les 3 CSV chargés.
-- =====================================================================

-- Vue de travail : chaque billet avec son motif de non-validité éventuel
-- Valide = séance existante, montant >= 0, date_billet <= début séance
CREATE OR REPLACE VIEW v_billets_qualifies AS
SELECT b.id_billet, b.id_spectateur, b.id_seance, b.date_billet,
       b.nb_places, b.montant, b.statut, b.id_groupe,
       s.id_cinema, s.categorie, s.capacite, s.debut,
       CASE
         WHEN s.id_seance IS NULL      THEN 'SEANCE_INEXISTANTE'
         WHEN b.montant < 0            THEN 'MONTANT_NEGATIF'
         WHEN b.date_billet > s.debut  THEN 'DATE_APRES_DEBUT'
       END AS motif_invalide
FROM   stg_billets b
LEFT JOIN stg_seances s ON s.id_seance = b.id_seance;

CREATE OR REPLACE VIEW v_billets_valides AS
SELECT * FROM v_billets_qualifies WHERE motif_invalide IS NULL;

-- Vue : identifiant de personne (email minuscule sans espaces ; sinon la ligne seule)
CREATE OR REPLACE VIEW v_personnes AS
SELECT id_spectateur,
       NVL(REPLACE(LOWER(email), ' ', ''), 'ID#' || id_spectateur) AS cle_personne
FROM   stg_spectateurs;

-- C1 · nombre de personnes distinctes
SELECT COUNT(DISTINCT cle_personne) AS c1_personnes FROM v_personnes;

-- C2 · opérations non valides, total et répartition par motif
SELECT NVL(motif_invalide, 'TOTAL') AS motif, COUNT(*) AS nb
FROM   v_billets_qualifies
WHERE  motif_invalide IS NOT NULL
GROUP  BY ROLLUP(motif_invalide)
ORDER  BY nb;

-- C3 · opérations valides confirmées
SELECT COUNT(*) AS c3_valides_confirmees
FROM   v_billets_valides
WHERE  statut = 'CONFIRMEE';

-- C4 · jour où le plus d'opérations valides ont été passées
SELECT TO_CHAR(jour, 'DD/MM/YYYY') AS jour, nb
FROM  (SELECT TRUNC(date_billet) AS jour, COUNT(*) AS nb,
              RANK() OVER (ORDER BY COUNT(*) DESC) AS rg
       FROM   v_billets_valides
       GROUP  BY TRUNC(date_billet))
WHERE rg = 1;

-- C5 · chiffre d'affaires de chaque site (valides confirmées)
SELECT c.id_cinema, c.ville, SUM(v.montant) AS c5_chiffre_affaires
FROM   v_billets_valides v
JOIN   stg_cinemas c ON c.id_cinema = v.id_cinema
WHERE  v.statut = 'CONFIRMEE'
GROUP  BY c.id_cinema, c.ville
ORDER  BY c.id_cinema;

-- C6 · personnes ayant des opérations valides sur au moins deux sites
SELECT COUNT(*) AS c6_personnes_multisites
FROM  (SELECT p.cle_personne
       FROM   v_billets_valides v
       JOIN   v_personnes p ON p.id_spectateur = v.id_spectateur
       GROUP  BY p.cle_personne
       HAVING COUNT(DISTINCT v.id_cinema) >= 2);

-- C7 · séances en sur-réservation (places valides confirmées > capacité)
SELECT COUNT(*) AS c7_seances_surreservees
FROM  (SELECT id_seance
       FROM   v_billets_valides
       WHERE  statut = 'CONFIRMEE'
       GROUP  BY id_seance, capacite
       HAVING SUM(nb_places) > capacite);

-- C8 · opérations groupées dont les opérations valides engagent >= 2 sites
SELECT COUNT(*) AS c8_groupes_multisites
FROM  (SELECT id_groupe
       FROM   v_billets_valides
       WHERE  id_groupe IS NOT NULL
       GROUP  BY id_groupe
       HAVING COUNT(DISTINCT id_cinema) >= 2);

-- C9 · places confirmées par catégorie de séance (valides confirmées)
SELECT categorie, SUM(nb_places) AS c9_places_confirmees
FROM   v_billets_valides
WHERE  statut = 'CONFIRMEE'
GROUP  BY categorie
ORDER  BY categorie;
