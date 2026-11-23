-- =====================================================================
-- Projet Data Storage Systems · groupe 09 · Cinéma indépendant
-- 06 · L2 · Dix requêtes métier (connexion CINE09, après 05)
-- Techniques imposées :
--   jointure externe ........ R1
--   HAVING .................. R2, R8
--   sous-requête corrélée ... R3
--   division ................ R4
--   fonction de fenêtrage ... R5, R6, R9
-- Chaque requête : énoncé métier, puis la requête. Résultats dans le
-- rapport (tableau L2) et captures A19 à A28.
-- =====================================================================

-- R1 · JOINTURE EXTERNE
-- Énoncé : dans chaque site, combien de spectateurs rattachés ont une
-- carte d'abonnement, combien n'en ont pas, et quel est le taux
-- d'équipement ? (les spectateurs sans carte sont gardés par la
-- jointure externe : ce sont eux que vise la campagne d'abonnement)
SELECT c.ville AS site_rattachement,
       COUNT(*)                                             AS nb_spectateurs,
       COUNT(ca.id_carte)                                   AS avec_carte,
       SUM(CASE WHEN ca.id_carte IS NULL THEN 1 ELSE 0 END) AS sans_carte,
       ROUND(100 * COUNT(ca.id_carte) / COUNT(*), 2)        AS taux_equipement_pct
FROM   spectateur sp
JOIN   cinema c ON c.id_cinema = sp.id_cinema
LEFT JOIN carte_abonnement ca ON ca.id_spectateur = sp.id_spectateur
GROUP  BY c.ville
ORDER  BY c.ville;

-- R2 · HAVING
-- Énoncé : quels spectateurs ont acheté au moins 33 billets confirmés
-- sur la période ? (cible d'un programme de fidélité)
SELECT sp.id_spectateur, sp.nom, sp.prenom, c.ville AS site_rattachement,
       COUNT(*)            AS nb_billets,
       SUM(b.nb_places)    AS nb_places,
       SUM(b.montant)      AS depense_totale
FROM   billet b
JOIN   spectateur sp ON sp.id_spectateur = b.id_spectateur
JOIN   cinema c      ON c.id_cinema      = sp.id_cinema
WHERE  b.statut = 'CONFIRMEE'
GROUP  BY sp.id_spectateur, sp.nom, sp.prenom, c.ville
HAVING COUNT(*) >= 33
ORDER  BY nb_billets DESC, depense_totale DESC, sp.id_spectateur;

-- R3 · SOUS-REQUÊTE CORRÉLÉE
-- Énoncé : quelles avant-premières ont un taux de remplissage supérieur
-- au taux moyen des avant-premières de leur propre site ?
-- (combien par site, et le meilleur taux)
SELECT c.ville,
       COUNT(*)                                        AS avp_au_dessus_moyenne_site,
       ROUND(MAX(s.places_confirmees / s.capacite) * 100, 1) AS meilleur_taux_pct
FROM   seance s
JOIN   cinema c ON c.id_cinema = s.id_cinema
WHERE  s.code_categorie = 'AVP'
AND    s.places_confirmees / s.capacite >
       (SELECT AVG(s2.places_confirmees / s2.capacite)
        FROM   seance s2
        WHERE  s2.code_categorie = 'AVP'
        AND    s2.id_cinema = s.id_cinema)          -- corrélation sur le site
GROUP  BY c.ville
ORDER  BY c.ville;

-- R4 · DIVISION
-- Énoncé : quels spectateurs ont assisté (billet confirmé) à au moins
-- une séance dans CHACUN des trois sites ? (spectateurs « réseau »,
-- cible de la carte d'abonnement commune)
-- Division par comptage : on garde le spectateur si le nombre de sites
-- où il a un billet confirmé est égal au nombre total de sites.
-- (La forme par double NOT EXISTS donne le même résultat mais relit les
--  billets pour chaque spectateur : elle a bloqué la session sur notre
--  volume ; elle est reprise comme requête lente au volet 4, L5.)
SELECT COUNT(*) AS spectateurs_dans_les_3_sites
FROM  (SELECT b.id_spectateur
       FROM   billet b
       JOIN   seance s ON s.id_seance = b.id_seance
       WHERE  b.statut = 'CONFIRMEE'
       GROUP  BY b.id_spectateur
       HAVING COUNT(DISTINCT s.id_cinema) = (SELECT COUNT(*) FROM cinema WHERE role = 'site'));

-- R5 · FENÊTRAGE (RANK)
-- Énoncé : dans chaque site, quelles sont les trois avant-premières les
-- plus remplies ? (ex aequo départagés par la date)
SELECT ville, id_seance, TO_CHAR(debut, 'DD/MM/YYYY HH24:MI') AS debut,
       capacite, places_confirmees, taux_pct, rang
FROM  (SELECT c.ville, s.id_seance, s.debut, s.capacite, s.places_confirmees,
              ROUND(s.places_confirmees / s.capacite * 100, 1) AS taux_pct,
              RANK() OVER (PARTITION BY s.id_cinema
                           ORDER BY s.places_confirmees / s.capacite DESC, s.debut) AS rang
       FROM   seance s
       JOIN   cinema c ON c.id_cinema = s.id_cinema
       WHERE  s.code_categorie = 'AVP')
WHERE  rang <= 3
ORDER  BY ville, rang;

-- R6 · FENÊTRAGE (cumul)
-- Énoncé : chiffre d'affaires trimestriel de chaque site en 2025, et
-- cumul depuis janvier (suivi budgétaire du siège)
SELECT ville, trimestre, ca_trimestre,
       SUM(ca_trimestre) OVER (PARTITION BY ville ORDER BY trimestre) AS ca_cumule
FROM  (SELECT c.ville, TO_CHAR(s.debut, 'YYYY-"T"Q') AS trimestre, SUM(b.montant) AS ca_trimestre
       FROM   billet b
       JOIN   seance s ON s.id_seance = b.id_seance
       JOIN   cinema c ON c.id_cinema = s.id_cinema
       WHERE  b.statut = 'CONFIRMEE'
       AND    s.debut >= DATE '2025-01-01' AND s.debut < DATE '2026-01-01'
       GROUP  BY c.ville, TO_CHAR(s.debut, 'YYYY-"T"Q'))
ORDER  BY ville, trimestre;

-- R7 · Agrégat conditionnel
-- Énoncé : taux d'annulation par catégorie de séance (en billets et en
-- places), pour repérer les catégories les moins fiables
SELECT cat.libelle AS categorie,
       COUNT(*) AS nb_billets,
       SUM(CASE WHEN b.statut = 'ANNULEE' THEN 1 ELSE 0 END) AS nb_annules,
       ROUND(100 * SUM(CASE WHEN b.statut = 'ANNULEE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS taux_annulation_pct,
       ROUND(100 * SUM(CASE WHEN b.statut = 'ANNULEE' THEN b.nb_places ELSE 0 END)
                 / SUM(b.nb_places), 2) AS taux_places_annulees_pct
FROM   billet b
JOIN   seance s     ON s.id_seance = b.id_seance
JOIN   categorie cat ON cat.code_categorie = s.code_categorie
GROUP  BY cat.libelle
ORDER  BY taux_annulation_pct DESC;

-- R8 · HAVING (opération groupée multi-sites)
-- Énoncé : combien de commandes groupées engagent au moins deux sites,
-- et quel est leur panier moyen (billets, montant) ?
SELECT COUNT(*)                 AS commandes_multisites,
       ROUND(AVG(nb_billets), 2) AS billets_moyens,
       ROUND(AVG(montant), 2)    AS montant_moyen,
       MAX(nb_sites)             AS max_sites
FROM  (SELECT b.id_commande, COUNT(*) AS nb_billets, SUM(b.montant) AS montant,
              COUNT(DISTINCT s.id_cinema) AS nb_sites
       FROM   billet b
       JOIN   seance s ON s.id_seance = b.id_seance
       WHERE  b.id_commande IS NOT NULL
       GROUP  BY b.id_commande
       HAVING COUNT(DISTINCT s.id_cinema) >= 2);

-- R9 · FENÊTRAGE (LAG) · pic de trafic
-- Énoncé : les 5 jours où l'on a vendu le plus de billets pour des
-- avant-premières, avec l'évolution par rapport à la veille
SELECT TO_CHAR(jour, 'DD/MM/YYYY') AS jour, billets_avp, billets_veille,
       billets_avp - billets_veille AS evolution
FROM  (SELECT jour, billets_avp,
              LAG(billets_avp, 1, 0) OVER (ORDER BY jour) AS billets_veille
       FROM  (SELECT TRUNC(b.date_billet) AS jour, COUNT(*) AS billets_avp
              FROM   billet b
              JOIN   seance s ON s.id_seance = b.id_seance
              WHERE  s.code_categorie = 'AVP'
              GROUP  BY TRUNC(b.date_billet)))
ORDER  BY billets_avp DESC
FETCH FIRST 5 ROWS ONLY;

-- R10 · Usage de la carte d'abonnement commune
-- Énoncé : pour chaque type de carte, combien de cartes sont utilisées
-- dans 1, 2 ou 3 sites, et pour combien d'entrées ? (intérêt d'une
-- carte valable dans tous les sites)
SELECT ca.type_carte,
       a.nb_sites          AS nb_sites_utilises,
       COUNT(*)            AS nb_cartes,
       SUM(a.entrees)      AS entrees
FROM   carte_abonnement ca
JOIN  (SELECT id_carte, COUNT(*) AS nb_sites, SUM(nb_entrees) AS entrees
       FROM   acces GROUP BY id_carte) a
       ON a.id_carte = ca.id_carte
GROUP  BY ca.type_carte, a.nb_sites
ORDER  BY ca.type_carte, nb_sites_utilises;
