-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- 03 · L1 · Création du modèle relationnel (connexion CINE09)
-- Toutes les contraintes sont nommées : pk_ (clé primaire), fk_ (clé
-- étrangère), uq_ (unicité), ck_ (vérification), nn_ (non nul).
-- Rejouable : supprime les tables du modèle si elles existent.
--
-- Règles portant sur plusieurs tables (impossibles en CHECK) :
--   RG2  séance programmée dans un site (pas au siège)     -> trigger, volet 3
--   RG8  billet acheté au plus tard au début de la séance   -> trigger, volet 3
--   RG10 places confirmées <= capacité de la séance          -> package, volet 3
--   RG12 commande groupée tout ou rien                       -> package, volet 3
-- Les clés étrangères ne sont volontairement pas indexées ici :
-- les index sont créés et mesurés au volet 4 (L5).
-- =====================================================================

BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('BILLET','ACCES','CARTE_PLACES','CARTE_ILLIMITEE',
                                 'CARTE_ABONNEMENT','COMMANDE','SEANCE','SPECTATEUR',
                                 'CATEGORIE','CINEMA')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

-- ---------------------------------------------------------------- CINEMA
-- RG1 : un siège et des sites
CREATE TABLE cinema (
  id_cinema   NUMBER(3)      CONSTRAINT pk_cinema PRIMARY KEY,
  nom         VARCHAR2(50)   CONSTRAINT nn_cinema_nom   NOT NULL,
  ville       VARCHAR2(50)   CONSTRAINT nn_cinema_ville NOT NULL,
  role        VARCHAR2(10)   CONSTRAINT nn_cinema_role  NOT NULL,
  CONSTRAINT uq_cinema_ville UNIQUE (ville),
  -- UNISTR('si\00e8ge') = 'siège', écrit sans accent pour ne pas dépendre de l'encodage du fichier
  CONSTRAINT ck_cinema_role  CHECK (role IN (UNISTR('si\00e8ge'), 'site'))
);

-- ------------------------------------------------------------- CATEGORIE
-- RG3 : cinq catégories de séance
CREATE TABLE categorie (
  code_categorie  VARCHAR2(5)   CONSTRAINT pk_categorie PRIMARY KEY,
  libelle         VARCHAR2(30)  CONSTRAINT nn_categorie_libelle NOT NULL,
  CONSTRAINT uq_categorie_libelle UNIQUE (libelle)
);

-- ------------------------------------------------------------ SPECTATEUR
-- RG5 : rattaché à un site ; RG6 : e-mail unique, en minuscules, sans espace
CREATE TABLE spectateur (
  id_spectateur     NUMBER(8)      CONSTRAINT pk_spectateur PRIMARY KEY,
  nom               VARCHAR2(60)   CONSTRAINT nn_spectateur_nom    NOT NULL,
  prenom            VARCHAR2(60)   CONSTRAINT nn_spectateur_prenom NOT NULL,
  email             VARCHAR2(120),
  telephone         VARCHAR2(10),
  ville             VARCHAR2(50),
  date_inscription  DATE           CONSTRAINT nn_spectateur_inscription NOT NULL,
  id_cinema         NUMBER(3)      CONSTRAINT nn_spectateur_cinema NOT NULL,
  CONSTRAINT fk_spectateur_cinema FOREIGN KEY (id_cinema) REFERENCES cinema (id_cinema),
  CONSTRAINT uq_spectateur_email  UNIQUE (email),
  CONSTRAINT ck_spectateur_email  CHECK (email = LOWER(email)
                                         AND REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
  CONSTRAINT ck_spectateur_tel    CHECK (REGEXP_LIKE(telephone, '^0[1-9][0-9]{8}$'))
);

-- ---------------------------------------------------------------- SEANCE
-- RG2 (site) ; RG3 (catégorie) ; RG4 (capacité, durée, prix positifs)
CREATE TABLE seance (
  id_seance       NUMBER(8)      CONSTRAINT pk_seance PRIMARY KEY,
  libelle         VARCHAR2(100)  CONSTRAINT nn_seance_libelle   NOT NULL,
  code_categorie  VARCHAR2(5)    CONSTRAINT nn_seance_categorie NOT NULL,
  id_cinema       NUMBER(3)      CONSTRAINT nn_seance_cinema    NOT NULL,
  debut           DATE           CONSTRAINT nn_seance_debut     NOT NULL,
  duree_minutes   NUMBER(4)      CONSTRAINT nn_seance_duree     NOT NULL,
  capacite        NUMBER(5)      CONSTRAINT nn_seance_capacite  NOT NULL,
  prix_unitaire   NUMBER(6,2)    CONSTRAINT nn_seance_prix      NOT NULL,
  CONSTRAINT fk_seance_categorie FOREIGN KEY (code_categorie) REFERENCES categorie (code_categorie),
  CONSTRAINT fk_seance_cinema    FOREIGN KEY (id_cinema)      REFERENCES cinema (id_cinema),
  CONSTRAINT ck_seance_duree     CHECK (duree_minutes BETWEEN 1 AND 600),
  CONSTRAINT ck_seance_capacite  CHECK (capacite > 0),
  CONSTRAINT ck_seance_prix      CHECK (prix_unitaire > 0)
);

-- -------------------------------------------------------------- COMMANDE
-- RG11 : une commande groupée a un seul payeur
CREATE TABLE commande (
  id_commande           VARCHAR2(10)  CONSTRAINT pk_commande PRIMARY KEY,
  id_spectateur_payeur  NUMBER(8)     CONSTRAINT nn_commande_payeur NOT NULL,
  date_commande         DATE          CONSTRAINT nn_commande_date   NOT NULL,
  CONSTRAINT fk_commande_payeur FOREIGN KEY (id_spectateur_payeur)
                                REFERENCES spectateur (id_spectateur)
);

-- ------------------------------------------------------ CARTE_ABONNEMENT
-- RG13 : une carte appartient à un spectateur
-- RG14 : héritage exclusif ; le couple (id_carte, type_carte) est unique
--        pour que chaque table fille ne puisse référencer que son type.
CREATE TABLE carte_abonnement (
  id_carte       NUMBER(8)  GENERATED BY DEFAULT AS IDENTITY
                             CONSTRAINT pk_carte PRIMARY KEY,
  id_spectateur  NUMBER(8)     CONSTRAINT nn_carte_spectateur NOT NULL,
  type_carte     VARCHAR2(10)  CONSTRAINT nn_carte_type       NOT NULL,
  date_debut     DATE          CONSTRAINT nn_carte_debut      NOT NULL,
  date_fin       DATE          CONSTRAINT nn_carte_fin        NOT NULL,
  CONSTRAINT fk_carte_spectateur FOREIGN KEY (id_spectateur) REFERENCES spectateur (id_spectateur),
  CONSTRAINT ck_carte_type       CHECK (type_carte IN ('ILLIMITEE', 'PLACES')),
  CONSTRAINT ck_carte_dates      CHECK (date_fin > date_debut),
  CONSTRAINT uq_carte_id_type    UNIQUE (id_carte, type_carte)
);

CREATE TABLE carte_illimitee (
  id_carte       NUMBER(8)     CONSTRAINT pk_carte_illimitee PRIMARY KEY,
  type_carte     VARCHAR2(10)  DEFAULT 'ILLIMITEE' CONSTRAINT nn_illimitee_type NOT NULL,
  tarif_mensuel  NUMBER(6,2)   CONSTRAINT nn_illimitee_tarif NOT NULL,
  CONSTRAINT fk_illimitee_carte FOREIGN KEY (id_carte, type_carte)
                                REFERENCES carte_abonnement (id_carte, type_carte),
  CONSTRAINT ck_illimitee_type  CHECK (type_carte = 'ILLIMITEE'),
  CONSTRAINT ck_illimitee_tarif CHECK (tarif_mensuel > 0)
);

CREATE TABLE carte_places (
  id_carte             NUMBER(8)     CONSTRAINT pk_carte_places PRIMARY KEY,
  type_carte           VARCHAR2(10)  DEFAULT 'PLACES' CONSTRAINT nn_places_type NOT NULL,
  nb_places_achetees   NUMBER(3)     CONSTRAINT nn_places_achetees  NOT NULL,
  nb_places_restantes  NUMBER(3)     CONSTRAINT nn_places_restantes NOT NULL,
  CONSTRAINT fk_places_carte     FOREIGN KEY (id_carte, type_carte)
                                 REFERENCES carte_abonnement (id_carte, type_carte),
  CONSTRAINT ck_places_type      CHECK (type_carte = 'PLACES'),
  CONSTRAINT ck_places_achetees  CHECK (nb_places_achetees > 0),
  CONSTRAINT ck_places_restantes CHECK (nb_places_restantes BETWEEN 0 AND nb_places_achetees)
);

-- ----------------------------------------------------------------- ACCES
-- RG15 : association porteuse CARTE_ABONNEMENT — CINEMA
CREATE TABLE acces (
  id_carte            NUMBER(8)  CONSTRAINT nn_acces_carte  NOT NULL,
  id_cinema           NUMBER(3)  CONSTRAINT nn_acces_cinema NOT NULL,
  date_premier_acces  DATE       CONSTRAINT nn_acces_date   NOT NULL,
  nb_entrees          NUMBER(5)  DEFAULT 0 CONSTRAINT nn_acces_entrees NOT NULL,
  CONSTRAINT pk_acces         PRIMARY KEY (id_carte, id_cinema),
  CONSTRAINT fk_acces_carte   FOREIGN KEY (id_carte)  REFERENCES carte_abonnement (id_carte),
  CONSTRAINT fk_acces_cinema  FOREIGN KEY (id_cinema) REFERENCES cinema (id_cinema),
  CONSTRAINT ck_acces_entrees CHECK (nb_entrees >= 0)
);

-- ---------------------------------------------------------------- BILLET
-- RG7 (places, montant, statut) ; RG11 (commande) ; RG16 (carte)
CREATE TABLE billet (
  id_billet      NUMBER(10)    CONSTRAINT pk_billet PRIMARY KEY,
  id_spectateur  NUMBER(8)     CONSTRAINT nn_billet_spectateur NOT NULL,
  id_seance      NUMBER(8)     CONSTRAINT nn_billet_seance     NOT NULL,
  id_commande    VARCHAR2(10),
  id_carte       NUMBER(8),
  date_billet    DATE          CONSTRAINT nn_billet_date    NOT NULL,
  nb_places      NUMBER(2)     CONSTRAINT nn_billet_places  NOT NULL,
  montant        NUMBER(8,2)   CONSTRAINT nn_billet_montant NOT NULL,
  statut         VARCHAR2(10)  CONSTRAINT nn_billet_statut  NOT NULL,
  CONSTRAINT fk_billet_spectateur FOREIGN KEY (id_spectateur) REFERENCES spectateur (id_spectateur),
  CONSTRAINT fk_billet_seance     FOREIGN KEY (id_seance)     REFERENCES seance (id_seance),
  CONSTRAINT fk_billet_commande   FOREIGN KEY (id_commande)   REFERENCES commande (id_commande),
  CONSTRAINT fk_billet_carte      FOREIGN KEY (id_carte)      REFERENCES carte_abonnement (id_carte),
  CONSTRAINT ck_billet_places     CHECK (nb_places BETWEEN 1 AND 10),
  CONSTRAINT ck_billet_montant    CHECK (montant >= 0),
  CONSTRAINT ck_billet_statut     CHECK (statut IN ('CONFIRMEE', 'ANNULEE'))
);

-- ------------------------------------------------- Données de référence
INSERT INTO cinema (id_cinema, nom, ville, role)
SELECT id_cinema, nom, ville, role FROM stg_cinemas;

-- Libellés repris des CSV (évite les problèmes d'accents) ; code court sans accent
INSERT INTO categorie (code_categorie, libelle)
SELECT CASE
         WHEN categorie LIKE 'avant%' THEN 'AVP'
         WHEN categorie LIKE 'jeune%' THEN 'JP'
         WHEN categorie LIKE 'cin%'   THEN 'CC'
         ELSE categorie                          -- VF, VO
       END,
       categorie
FROM  (SELECT DISTINCT categorie FROM stg_seances);
COMMIT;

-- ---------------------------------------------------------- Vérification
-- 10 tables et leurs contraintes nommées
SELECT table_name,
       SUM(CASE constraint_type WHEN 'P' THEN 1 ELSE 0 END) AS pk,
       SUM(CASE constraint_type WHEN 'R' THEN 1 ELSE 0 END) AS fk,
       SUM(CASE constraint_type WHEN 'U' THEN 1 ELSE 0 END) AS uq,
       SUM(CASE WHEN constraint_type = 'C' AND constraint_name LIKE 'CK%' THEN 1 ELSE 0 END) AS ck,
       SUM(CASE WHEN constraint_type = 'C' AND constraint_name LIKE 'NN%' THEN 1 ELSE 0 END) AS nn
FROM   user_constraints
WHERE  table_name IN ('CINEMA','CATEGORIE','SPECTATEUR','SEANCE','COMMANDE','CARTE_ABONNEMENT',
                      'CARTE_ILLIMITEE','CARTE_PLACES','ACCES','BILLET')
GROUP  BY table_name
ORDER  BY table_name;
