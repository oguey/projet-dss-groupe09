# Notes pour le L5 · requêtes lentes (passation)

Le sujet demande au L5 : « trois requêtes lentes sur votre volume, leur plan avant et après optimisation,
avec les blocs lus mesurés ». Cette note donne une première requête lente, déjà rencontrée, et la façon
de la mesurer **sans bloquer le serveur**.

## Point de départ : aucun index sur les clés étrangères

Volontairement, le script 03 ne crée **aucun index** sur les clés étrangères (`billet.id_spectateur`,
`billet.id_seance`, `seance.id_cinema`…). Seules existent les clés primaires et les contraintes d'unicité.
Les requêtes qui suivent un spectateur ou une séance dans les 378 202 billets lisent donc toute la table.
C'est la situation « avant » ; les index créés au L5 donnent la situation « après ».

## Requête lente n° 1 : la division par double NOT EXISTS (incident du 23/11)

Première version de la requête R4 (spectateurs venus dans chacun des trois sites). Résultat attendu : 3 459.

```sql
WITH frequente AS (
  SELECT DISTINCT b.id_spectateur, s.id_cinema
  FROM   billet b
  JOIN   seance s ON s.id_seance = b.id_seance
  WHERE  b.statut = 'CONFIRMEE')
SELECT COUNT(*) AS spectateurs_dans_les_3_sites
FROM   spectateur sp
WHERE  NOT EXISTS (
         SELECT 1 FROM cinema c
         WHERE  c.role = 'site'
         AND    NOT EXISTS (
                  SELECT 1 FROM frequente f
                  WHERE  f.id_spectateur = sp.id_spectateur
                  AND    f.id_cinema     = c.id_cinema));
```

**Incident** : lancée le 23/11 sans index, cette requête n'a pas rendu la main. La session SQL Developer
est restée bloquée, et même F5 sur d'autres scripts ne répondait plus. Il a fallu fermer SQL Developer et
redémarrer Oracle (`docker compose restart oracle`). Aucune donnée perdue. Dans le script 06, R4 a été
réécrite en division par comptage (même résultat, 3 459, en moins d'une seconde).

### ⚠️ Comment la mesurer sans bloquer le serveur

1. **Plan « avant » sans exécuter la requête** : `EXPLAIN PLAN` calcule le plan sans lancer la requête.
   ```sql
   EXPLAIN PLAN FOR
   <la requête ci-dessus>;
   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
   ```
   On y voit les accès complets (`TABLE ACCESS FULL BILLET`) répétés et le coût estimé.
2. **Ne pas l'exécuter réellement avant d'avoir créé les index.** Si on veut quand même mesurer le temps
   « avant », le faire avec une limite : SQL Developer → bouton **Annuler** après 60 secondes, et noter
   « interrompue après 60 s » comme mesure.
3. **Optimisation proposée** : index sur les colonnes de jointure, puis statistiques à jour.
   ```sql
   CREATE INDEX ix_billet_spectateur ON billet (id_spectateur, statut, id_seance);
   CREATE INDEX ix_billet_seance     ON billet (id_seance);
   CREATE INDEX ix_seance_cinema     ON seance (id_cinema);
   EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
   ```
4. **Plan et blocs lus « après »** : exécuter la requête avec les statistiques d'exécution, par exemple
   `/*+ GATHER_PLAN_STATISTICS */` puis
   `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));`
   (colonne **Buffers** = blocs lus), ou la touche **F6** (Autotrace) de SQL Developer.
5. Comparer aussi avec la version par comptage de R4 (script 06) : c'est une autre optimisation possible,
   par réécriture de la requête plutôt que par index.

## Autres candidates (non encore mesurées)

- **Historique d'un spectateur** : `SELECT … FROM billet WHERE id_spectateur = :id` (accès complet sans index
  sur `id_spectateur`).
- **Vérification de capacité « à la volée »** (option A de l'ADR-01) :
  `SELECT SUM(nb_places) FROM billet WHERE id_seance = :id AND statut = 'CONFIRMEE'`, à comparer à la lecture
  de `seance.places_confirmees`. Les blocs lus mesurés ici complètent l'ADR-01 (rubrique 4, « [À MESURER] »).
- **CA par site et par mois** (R6) : candidate pour la **vue matérialisée** demandée au L5.

## Rappel des mesures déjà connues

- Table à plat `BILLET_A_PLAT` : 80 Mo, 10 240 blocs (L3, annexe A13).
- BILLET : 378 202 lignes ; SEANCE : 7 519 ; SPECTATEUR : 20 732.
