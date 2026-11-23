# ADR-01 · Stocker les places confirmées dans la séance pour refuser la sur-réservation

**Statut** : proposé le 23/11/2026 (premier jet ; mesures [À MESURER] complétées aux volets 2 à 4).

> ⚠️ Contrainte imposée : [À DEMANDER À L'ENSEIGNANTE] — à intégrer au contexte, aux options et à la décision.

## 1. Contexte

À chaque vente, la base doit refuser la sur-réservation (RG10 : places confirmées ≤ capacité) et vendre une
commande groupée multi-sites en tout ou rien (RG12). Nos données : 7 519 séances de 80 à 300 places,
378 708 billets, soit 50,3 billets par séance en moyenne (L3, annexe A13). Le pic de trafic est celui des
avant-premières : 16 042 opérations valides le 11/02/2026 (C4, annexe A4), contre 625 le deuxième jour le plus
chargé. Les fichiers contiennent déjà **20 séances en sur-réservation** (C7, annexe A7) : la règle n'a pas été
tenue par le système d'origine.

## 2. Options envisagées

- **A. Calcul à la volée** (Oracle, modèle 3NF) : `SUM(nb_places)` des billets confirmés de la séance, avec un
  index sur `billet(id_seance, statut)`.
- **B. Colonne dénormalisée** (Oracle) : `SEANCE.places_confirmees`, maintenue par trigger, ligne de séance
  verrouillée par `SELECT … FOR UPDATE` dans le package de vente.
- **C. Vue matérialisée** (Oracle) : places par séance, `REFRESH FAST ON COMMIT`.
- **D. Compteur Redis** : `DECRBY places:<id_seance>` atomique devant Oracle pendant le pic.

## 3. Critères

| Critère | A · calcul à la volée | B · colonne + trigger | C · vue matérialisée | D · compteur Redis |
|---|---|---|---|---|
| Cohérence | ++ (toujours exact) | + (exacte si tout passe par le trigger) | − (rafraîchie au commit : deux ventes simultanées ne se voient pas) | − (deux systèmes à réconcilier) |
| Concurrence (dernière place) | − (deux sessions additionnent la même somme) | ++ (verrou sur une ligne) | −− | ++ (opération atomique) |
| Latence à la vente | − [À MESURER : blocs lus] | ++ [À MESURER] | + | ++ |
| Volumétrie | − (croît avec les billets) | ++ (une ligne par séance) | + | ++ |
| Coût d'exploitation | ++ (rien à ajouter) | + (un trigger) | + | − (un moteur de plus) |
| Sécurité, chiffrement | ++ (Oracle) | ++ (Oracle) | ++ | − (sans authentification dans le kit) |

## 4. Mesures

- Redondance : 50,3 billets par séance à additionner en moyenne (annexe A13).
- Pic : 16 042 opérations le 11/02/2026 (annexe A4).
- Sur-réservation existante : 20 séances (annexe A7).
- [À MESURER au volet 4] blocs lus par la vérification de capacité, option A (avec et sans index) contre option B.
- [À MESURER au volet 3] anomalie de concurrence : deux sessions achètent la dernière place ; résultat avec A et avec B.

## 5. Décision

Nous choisissons **B** parce que la vérification de capacité lit une seule ligne verrouillable, ce qui règle à la
fois la latence au pic et la concurrence sur la dernière place, sans ajouter de moteur.

## 6. Conséquences et risques

- **Facile** : refuser la sur-réservation dans le package de vente ; afficher les places restantes sans calcul.
- **Difficile** : toute écriture sur BILLET doit passer par le trigger (insertion, annulation, suppression,
  changement de séance) ; un chargement en masse qui désactive les triggers doit recalculer la colonne.
- **Risque : dérive de la colonne**. Parade : requête de cohérence (`places_confirmees` = somme des billets)
  dans les contrôles du volet 2, à relancer après chaque chargement.
- **Risque : contention** au pic, toutes les ventes d'une même avant-première attendant le verrou de sa ligne.
  Seuil : si l'attente sur ce verrou dépasse [À MESURER] ms au pic, nous ajouterons l'option D (Redis) devant Oracle.

## 7. Volet RGPD

- **Données personnelles** : la colonne est un **agrégat anonyme** (un nombre par séance) ; elle ne contient
  aucune donnée personnelle. Les billets, eux, rattachent un spectateur (nom, e-mail, téléphone) à une séance.
- **Minimisation** : le contrôle de capacité et l'affichage des places restantes n'ont besoin que de la colonne,
  pas des billets : les comptes de vente des sites peuvent lire SEANCE sans accès aux données des spectateurs (L5).
- **Conservation** : [À DÉFINIR, par exemple billets conservés 3 ans après la séance pour la comptabilité,
  puis anonymisés] ; la colonne, anonyme, est conservée avec la séance.
- **Effacement** : supprimer ou anonymiser les billets d'un spectateur déclenche le trigger qui met la colonne à
  jour ; les copies (vues matérialisées, schémas des sites au volet 6, sauvegardes) suivent [À PRÉCISER au volet 5].
- **Localisation** : base Oracle hébergée en France (kit local) ; aucun transfert hors de l'Union européenne.

## 8. Liens

L1 (RG10, RG12), L3 (dénormalisation), L4 (trigger et package de vente), L5 (mesures des blocs lus), ADR-02.
