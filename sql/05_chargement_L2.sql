-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- 05 · L2 · Chargement des tables du modèle à partir des tables brutes
--      STG_*, avec traitement des défauts (connexion CINE09).
-- Prérequis : 01 (STG_*), 03 (modèle), 04 (colonne places_confirmees).
-- Rejouable : vide les tables du modèle (sauf CINEMA, CATEGORIE) et
-- recharge tout.
--
-- Traitement des défauts (tous tracés dans JOURNAL_CHARGEMENT) :
--   FUSION     88 spectateurs en double (même e-mail en minuscules sans
--              espaces) : on garde la fiche au plus petit identifiant,
--              ses billets lui sont réattribués.
--   REJET      billets non valides au sens du sujet (séance inexistante,
--              montant négatif, achat après le début de la séance),
--              billet en double exact, billets qui dépassent la capacité
--              de leur séance (les derniers vendus).
--   CORRECTION billets réattribués au spectateur conservé.
--   AJOUT      cartes d'abonnement générées (données ajoutées).
-- Les tables STG_* ne sont jamais modifiées : C1 à C9 restent calculables.
-- =====================================================================

-- ---------------------------------------------------- 0. Préparation
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('JOURNAL_CHARGEMENT','MAP_SPECTATEUR','W_BILLET')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
  END LOOP;
END;
/

-- Vidage des tables du modèle (ordre des clés étrangères)
DELETE FROM acces;
DELETE FROM carte_places;
DELETE FROM carte_illimitee;
DELETE FROM billet;
DELETE FROM carte_abonnement;
DELETE FROM commande;
DELETE FROM seance;
DELETE FROM spectateur;
COMMIT;

-- Journal de chargement : une ligne par défaut traité
CREATE TABLE journal_chargement (
  id_journal    NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_journal PRIMARY KEY,
  table_source  VARCHAR2(20)  CONSTRAINT nn_journal_table  NOT NULL,
  id_source     VARCHAR2(20)  CONSTRAINT nn_journal_id     NOT NULL,
  action        VARCHAR2(12)  CONSTRAINT nn_journal_action NOT NULL,
  motif         VARCHAR2(30)  CONSTRAINT nn_journal_motif  NOT NULL,
  detail        VARCHAR2(400),
  date_journal  DATE DEFAULT SYSDATE CONSTRAINT nn_journal_date NOT NULL,
  CONSTRAINT ck_journal_action CHECK (action IN ('FUSION', 'REJET', 'CORRECTION', 'AJOUT'))
);

-- --------------------------------------------------- 1. Spectateurs
-- Correspondance fiche source -> fiche conservée (plus petit identifiant
-- parmi les fiches de même e-mail normalisé ; sans e-mail : elle-même)
CREATE TABLE map_spectateur (
  id_source  NUMBER(8) CONSTRAINT pk_map_spectateur PRIMARY KEY,
  id_cible   NUMBER(8) CONSTRAINT nn_map_cible NOT NULL
);

INSERT INTO map_spectateur (id_source, id_cible)
SELECT id_spectateur,
       MIN(id_spectateur) OVER (PARTITION BY NVL(REPLACE(LOWER(email), ' ', ''),
                                                 'ID#' || id_spectateur))
FROM   stg_spectateurs;

INSERT INTO spectateur (id_spectateur, nom, prenom, email, telephone, ville,
                        date_inscription, id_cinema)
SELECT s.id_spectateur, s.nom, s.prenom,
       REPLACE(LOWER(s.email), ' ', ''),
       s.telephone, s.ville, s.date_inscription, s.id_cinema
FROM   stg_spectateurs s
JOIN   map_spectateur m ON m.id_source = s.id_spectateur
WHERE  m.id_cible = m.id_source;

INSERT INTO journal_chargement (table_source, id_source, action, motif, detail)
SELECT 'SPECTATEUR', TO_CHAR(m.id_source), 'FUSION', 'DOUBLON_EMAIL',
       'fiche fusionnée avec le spectateur ' || m.id_cible || ' (e-mail : ' || s.email || ')'
FROM   map_spectateur m
JOIN   stg_spectateurs s ON s.id_spectateur = m.id_source
WHERE  m.id_cible <> m.id_source;

-- Trace des e-mails modifiés par la normalisation sur les fiches conservées
INSERT INTO journal_chargement (table_source, id_source, action, motif, detail)
SELECT 'SPECTATEUR', TO_CHAR(s.id_spectateur), 'CORRECTION', 'EMAIL_NORMALISE',
       '"' || s.email || '" -> "' || REPLACE(LOWER(s.email), ' ', '') || '"'
FROM   stg_spectateurs s
JOIN   map_spectateur m ON m.id_source = s.id_spectateur AND m.id_cible = m.id_source
WHERE  s.email <> REPLACE(LOWER(s.email), ' ', '');

-- ------------------------------------------------------- 2. Séances
INSERT INTO seance (id_seance, libelle, code_categorie, id_cinema, debut,
                    duree_minutes, capacite, prix_unitaire)
SELECT s.id_seance, s.libelle, c.code_categorie, s.id_cinema, s.debut,
       s.duree_minutes, s.capacite, s.prix_unitaire
FROM   stg_seances s
JOIN   categorie c ON c.libelle = s.categorie;

-- ------------------------------------------- 3. Qualification des billets
-- Table de travail : chaque billet brut, son spectateur réattribué et son
-- éventuel motif de rejet (ordre des motifs identique à C2).
CREATE TABLE w_billet AS
SELECT b.id_billet, b.id_spectateur AS id_spectateur_source, m.id_cible AS id_spectateur,
       b.id_seance, b.date_billet, b.nb_places, b.montant, b.statut, b.id_groupe,
       s.capacite,
       CAST(CASE
              WHEN s.id_seance IS NULL     THEN 'SEANCE_INEXISTANTE'
              WHEN b.montant < 0           THEN 'MONTANT_NEGATIF'
              WHEN b.date_billet > s.debut THEN 'DATE_APRES_DEBUT'
              WHEN ROW_NUMBER() OVER (PARTITION BY m.id_cible, b.id_seance, b.date_billet,
                                                   b.nb_places, b.montant, b.statut, b.id_groupe
                                      ORDER BY b.id_billet) > 1
                                           THEN 'DOUBLON_BILLET'
            END AS VARCHAR2(30)) AS motif
FROM   stg_billets b
JOIN   map_spectateur m ON m.id_source = b.id_spectateur
LEFT JOIN stg_seances s ON s.id_seance = b.id_seance;

-- RG10 : on rejette les billets confirmés vendus après que la séance était
-- pleine (cumul des places dans l'ordre chronologique des ventes).
UPDATE w_billet
SET    motif = 'SURRESERVATION'
WHERE  id_billet IN (
         SELECT id_billet
         FROM  (SELECT id_billet, capacite,
                       SUM(nb_places) OVER (PARTITION BY id_seance
                                            ORDER BY date_billet, id_billet) AS cumul
                FROM   w_billet
                WHERE  motif IS NULL AND statut = 'CONFIRMEE')
         WHERE cumul > capacite);

-- ------------------------------------------------------ 4. Commandes
-- Une commande par id_groupe ; payeur et date = ceux du premier billet valide.
INSERT INTO commande (id_commande, id_spectateur_payeur, date_commande)
SELECT id_groupe, id_spectateur, date_billet
FROM  (SELECT id_groupe, id_spectateur, date_billet,
              ROW_NUMBER() OVER (PARTITION BY id_groupe ORDER BY date_billet, id_billet) AS rn
       FROM   w_billet
       WHERE  motif IS NULL AND id_groupe IS NOT NULL)
WHERE  rn = 1;

-- -------------------------------------------------------- 5. Billets
INSERT INTO billet (id_billet, id_spectateur, id_seance, id_commande, id_carte,
                    date_billet, nb_places, montant, statut)
SELECT id_billet, id_spectateur, id_seance, id_groupe, NULL,
       date_billet, nb_places, montant, statut
FROM   w_billet
WHERE  motif IS NULL;

INSERT INTO journal_chargement (table_source, id_source, action, motif, detail)
SELECT 'BILLET', TO_CHAR(id_billet), 'REJET', motif,
       'séance ' || id_seance || ', spectateur ' || id_spectateur_source
       || ', ' || nb_places || ' place(s), ' || TO_CHAR(montant, 'FM99990.00') || ' EUR, '
       || statut || ', acheté le ' || TO_CHAR(date_billet, 'DD/MM/YYYY HH24:MI')
FROM   w_billet
WHERE  motif IS NOT NULL;

INSERT INTO journal_chargement (table_source, id_source, action, motif, detail)
SELECT 'BILLET', TO_CHAR(id_billet), 'CORRECTION', 'SPECTATEUR_FUSIONNE',
       'spectateur ' || id_spectateur_source || ' -> ' || id_spectateur
FROM   w_billet
WHERE  motif IS NULL AND id_spectateur <> id_spectateur_source;

-- ---------------------------------- 6. Colonne dénormalisée (ADR-01)
-- (MERGE sur un agrégat : une seule lecture des billets ; une sous-requête
--  corrélée relirait les 378 000 billets pour chacune des 7 519 séances)
MERGE INTO seance s
USING (SELECT id_seance, SUM(nb_places) AS places
       FROM   billet
       WHERE  statut = 'CONFIRMEE'
       GROUP  BY id_seance) b
ON (s.id_seance = b.id_seance)
WHEN MATCHED THEN UPDATE SET s.places_confirmees = b.places;

-- RG10 désormais garantie par une contrainte sur la ligne de la séance
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM user_constraints
  WHERE  constraint_name = 'CK_SEANCE_CAPACITE_RESPECTEE';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE seance ADD CONSTRAINT ck_seance_capacite_respectee '
                   || 'CHECK (places_confirmees <= capacite)';
  END IF;
END;
/

-- ------------------------------ 7. Cartes d'abonnement (données ajoutées)
-- Les fichiers ne contiennent pas de cartes. On en crée une pour chaque
-- spectateur fidèle en 2025 (au moins 15 billets confirmés dans l'année) :
-- illimitée à partir de 18 billets, à 20 places sinon. Les billets
-- existants ne sont pas modifiés (leur montant montre qu'ils ont été payés
-- au plein tarif) ; ACCES résume, par site, les entrées de l'année.
INSERT INTO carte_abonnement (id_carte, id_spectateur, type_carte, date_debut, date_fin)
SELECT ROW_NUMBER() OVER (ORDER BY id_spectateur),
       id_spectateur,
       CASE WHEN nb >= 18 THEN 'ILLIMITEE' ELSE 'PLACES' END,
       DATE '2025-01-01', DATE '2026-01-01'
FROM  (SELECT id_spectateur, COUNT(*) AS nb
       FROM   billet
       WHERE  statut = 'CONFIRMEE'
       AND    date_billet >= DATE '2025-01-01' AND date_billet < DATE '2026-01-01'
       GROUP  BY id_spectateur
       HAVING COUNT(*) >= 15);

INSERT INTO carte_illimitee (id_carte, type_carte, tarif_mensuel)
SELECT id_carte, 'ILLIMITEE', 21.90
FROM   carte_abonnement WHERE type_carte = 'ILLIMITEE';

INSERT INTO carte_places (id_carte, type_carte, nb_places_achetees, nb_places_restantes)
SELECT c.id_carte, 'PLACES', 20, GREATEST(0, 20 - NVL(SUM(a.nb_entrees), 0))
FROM   carte_abonnement c
LEFT JOIN (SELECT c2.id_carte, COUNT(*) AS nb_entrees
           FROM   carte_abonnement c2
           JOIN   billet b ON b.id_spectateur = c2.id_spectateur
                          AND b.statut = 'CONFIRMEE'
                          AND b.date_billet >= c2.date_debut AND b.date_billet < c2.date_fin
           GROUP  BY c2.id_carte) a ON a.id_carte = c.id_carte
WHERE  c.type_carte = 'PLACES'
GROUP  BY c.id_carte;

INSERT INTO acces (id_carte, id_cinema, date_premier_acces, nb_entrees)
SELECT c.id_carte, s.id_cinema, MIN(b.date_billet), COUNT(*)
FROM   carte_abonnement c
JOIN   billet b ON b.id_spectateur = c.id_spectateur
               AND b.statut = 'CONFIRMEE'
               AND b.date_billet >= c.date_debut AND b.date_billet < c.date_fin
JOIN   seance s ON s.id_seance = b.id_seance
GROUP  BY c.id_carte, s.id_cinema;

INSERT INTO journal_chargement (table_source, id_source, action, motif, detail)
SELECT 'CARTE_ABONNEMENT', TO_CHAR(id_carte), 'AJOUT', 'CARTE_GENEREE',
       'carte ' || type_carte || ' du spectateur ' || id_spectateur || ' pour 2025'
FROM   carte_abonnement;

COMMIT;

DROP TABLE w_billet PURGE;

-- ---------------------------------------------------- 8. Contrôles
-- 8a. Lignes chargées par table
SELECT 'SPECTATEUR' AS table_modele, COUNT(*) AS nb_lignes FROM spectateur
UNION ALL SELECT 'SEANCE',           COUNT(*) FROM seance
UNION ALL SELECT 'COMMANDE',         COUNT(*) FROM commande
UNION ALL SELECT 'BILLET',           COUNT(*) FROM billet
UNION ALL SELECT 'CARTE_ABONNEMENT', COUNT(*) FROM carte_abonnement
UNION ALL SELECT 'CARTE_ILLIMITEE',  COUNT(*) FROM carte_illimitee
UNION ALL SELECT 'CARTE_PLACES',     COUNT(*) FROM carte_places
UNION ALL SELECT 'ACCES',            COUNT(*) FROM acces;

-- 8b. Défauts traités, par action et par motif
SELECT table_source, action, motif, COUNT(*) AS nb
FROM   journal_chargement
GROUP  BY table_source, action, motif
ORDER  BY table_source, action, nb DESC;

-- 8c. Bilan : chaque ligne des fichiers est chargée ou rejetée (aucune perte)
SELECT 'spectateurs' AS fichier,
       (SELECT COUNT(*) FROM stg_spectateurs) AS lignes_fichier,
       (SELECT COUNT(*) FROM spectateur)      AS chargees,
       (SELECT COUNT(*) FROM journal_chargement
        WHERE table_source = 'SPECTATEUR' AND action = 'FUSION') AS fusionnees_ou_rejetees
FROM dual
UNION ALL
SELECT 'billets',
       (SELECT COUNT(*) FROM stg_billets),
       (SELECT COUNT(*) FROM billet),
       (SELECT COUNT(*) FROM journal_chargement
        WHERE table_source = 'BILLET' AND action = 'REJET')
FROM dual;

-- 8d. Cohérence de la colonne dénormalisée (attendu : 0 écart)
SELECT COUNT(*) AS ecarts_places_confirmees
FROM   seance s
LEFT JOIN (SELECT id_seance, SUM(nb_places) AS places
           FROM   billet WHERE statut = 'CONFIRMEE'
           GROUP  BY id_seance) b ON b.id_seance = s.id_seance
WHERE  s.places_confirmees <> NVL(b.places, 0);
