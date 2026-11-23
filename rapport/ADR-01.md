# ADR-01 · Stocker les places confirmées dans la séance

**Statut** : 23/11/2026 — Proposé et décidé après le chargement


## Le problème

La base doit refuser la sur-réservation (RG10 : places confirmées ≤ capacité). Problème : les données contiennent déjà **20 séances en sur-réservation** — l'ancien système n'a pas contrôlé ça.

**Chiffres** :
- 7 519 séances de 80 à 300 places
- 378 708 billets = ~50 billets par séance en moyenne
- Pic : 16 042 ventes le 11/02/2026 (avant-premières)

## Solutions envisagées

| Option | Description | Avantages | Problèmes |
|--------|-------------|-----------|----------|
| **A** | Calculer à la volée (`SUM(nb_places)` depuis BILLET) | Pas de redondance | Lent au pic, risque de doublon |
| **B** | Colonne `SEANCE.places_confirmees` + trigger | Rapide, une ligne verrouillée, simple | Trigger obligatoire à chaque écriture |
| **C** | Vue matérialisée rafraîchie au commit | Pas mal | Deux ventes simultanées pas visibles |
| **D** | Compteur Redis | Ultra-rapide | Deux systèmes à réconcilier, sécurité |

## Décision : Option B

**Pourquoi** : verrouille une seule ligne (la séance), règle la concurrence et ne ralentit pas le pic.

**Ce qu'on fait** :
- Une colonne `places_confirmees` dans SEANCE
- Un trigger sur BILLET pour mettre à jour la colonne
- Un verrou `SELECT … FOR UPDATE` lors de chaque vente
- Contrainte CHECK : `places_confirmees <= capacite`

**Risques** :
- Si un chargement désactive les triggers, il faut recalculer la colonne après
- Au pic, tous les achats d'une même séance attendent le verrou

**À mesurer plus tard** :
- Latence au pic (option A vs B)
- Concurrence : deux sessions achètent la dernière place
- Contention du verrou si elle dépasse [valeur], on ajoute Redis devant

## RGPD

- La colonne = nombre anonyme (pas de données perso)
- Supprimer/anonymiser les billets d'un spectateur met la colonne à jour automatiquement (trigger)
- Conservation : [À DÉFINIR, ex: billets 3 ans après la séance]
