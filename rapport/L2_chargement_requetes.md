# L2 · Chargement et requêtes — Groupe 09

Scripts : `sql/01_staging.sql`, `sql/02_controle_C1_C9.sql`, `sql/05_chargement_L2.sql`,
`sql/06_requetes_metier_L2.sql` · captures A1 à A9 (C1 à C9), A15 à A18 (chargement), A19 à A28 (requêtes).

## 1. Chargement en deux temps

1. **Chargement brut** (script 01) : les CSV sont lus par des tables externes Oracle et copiés tels quels dans
   des tables `STG_*`, sans aucune contrainte métier. Les valeurs de contrôle C1 à C9 sont calculées sur ces
   tables, donc sur les fichiers d'origine (script 02, annexes A1 à A9).
2. **Chargement propre** (script 05) : les tables du modèle sont remplies à partir des `STG_*`. Chaque défaut est
   traité et tracé dans `JOURNAL_CHARGEMENT` (une ligne par défaut, avec action, motif et détail). Les `STG_*`
   ne sont jamais modifiées.

## 2. Traitement des défauts

| Défaut détecté | Volume | Traitement | Justification |
|---|---|---|---|
| Même personne sur plusieurs fiches (e-mail identique après minuscules et suppression des espaces) | 88 fiches | **FUSION** dans la fiche au plus petit identifiant ; 823 billets réattribués (**CORRECTION**) | règle RG6 : une personne, une fiche ; aucun billet perdu |
| Billet sur une séance inexistante | 301 | **REJET** | clé étrangère impossible ; ni site ni prix connus |
| Montant négatif | 77 | **REJET** | contrainte `ck_billet_montant` ; la valeur absolue serait une supposition |
| Billet acheté après le début de la séance | 102 | **REJET** | règle RG8 ; définition d'une opération valide du sujet |
| Billet en double exact (même spectateur, séance, date, places, montant, statut, groupe) | 1 | **REJET** du second | un achat enregistré deux fois |
| Séance sur-réservée : billets confirmés vendus après que la séance était pleine | 25 billets (82 places, 20 séances = C7) | **REJET** des derniers vendus | règle RG10 ; permet d'imposer la contrainte `ck_seance_capacite_respectee` |
| Pas de cartes d'abonnement dans les fichiers | — | **AJOUT** de 703 cartes (85 illimitées, 618 à places) pour les spectateurs ayant au moins 15 billets confirmés en 2025 | le sujet autorise l'ajout de données ; les billets existants ne sont pas modifiés |

Défauts conservés, mais signalés : 157 billets achetés avant la date d'inscription du spectateur (aucune règle ne
l'interdit : l'inscription a pu être faite après un premier achat au guichet).

## 3. Bilan : aucune ligne perdue (annexes A15 à A18)

| Fichier | Lignes du fichier | Chargées | Fusionnées ou rejetées |
|---|---|---|---|
| spectateurs.csv | 20 820 | 20 732 | 88 |
| billets.csv | 378 708 | 378 202 | 506 |

Tables du modèle : SPECTATEUR 20 732 · SEANCE 7 519 · COMMANDE 2 169 · BILLET 378 202 · CARTE_ABONNEMENT 703
(CARTE_ILLIMITEE 85, CARTE_PLACES 618) · ACCES 1 401. La colonne dénormalisée `places_confirmees` est cohérente
avec les billets (0 écart, annexe A18).

## 4. Les dix requêtes métier (annexes A19 à A28)

| N° | Technique | Énoncé | Résultat | Annexe |
|---|---|---|---|---|
| R1 | **jointure externe** | taux d'équipement en carte des spectateurs par site | Metz 300/9 576 (3,13 %), Nancy 138/4 637 (2,98 %), Reims 265/6 519 (4,07 %) | A19 |
| R2 | **HAVING** | spectateurs ayant au moins 33 billets confirmés | 12 spectateurs, de 33 à 37 billets | A20 |
| R3 | **sous-requête corrélée** | avant-premières plus remplies que la moyenne des avant-premières de leur site | Metz 325, Nancy 158, Reims 266 | A21 |
| R4 | **division** | spectateurs venus dans chacun des trois sites | 3 459 | A22 |
| R5 | **fenêtrage** (RANK) | trois avant-premières les plus remplies par site | 9 séances, de 91,4 % à 99,3 % | A23 |
| R6 | **fenêtrage** (SUM cumulée) | CA trimestriel 2025 et cumul par site | cumul 2025 : Metz 1 733 784 €, Nancy 784 763 €, Reims 1 180 356 € | A24 |
| R7 | agrégat conditionnel | taux d'annulation par catégorie | de 7,75 % (avant-première) à 7,98 % (VO) | A25 |
| R8 | **HAVING** | commandes groupées engageant au moins deux sites | 1 521 commandes, 3,01 billets et 25,53 € en moyenne | A26 |
| R9 | **fenêtrage** (LAG) | cinq meilleurs jours de vente d'avant-premières | 11/02/2026 : 3 173 billets (61 la veille) | A27 |
| R10 | jointure | cartes utilisées dans 1, 2 ou 3 sites | 219 cartes utilisées dans les trois sites | A28 |

Remarques :
- **R8 (1 521) et C8 (1 522)** diffèrent d'une commande : C8 est calculée sur les fichiers, R8 sur la base
  nettoyée, où un billet rejeté au chargement retire son second site à une commande.
- **R9** mesure le pic de trafic du sujet : 3 173 billets d'avant-premières en une journée, contre 150 au plus
  les autres jours.
- **R4** a d'abord été écrite en double `NOT EXISTS` : correcte, mais elle a bloqué la session sur notre volume
  (voir journal de bord). Elle a été réécrite en division par comptage, avec le même résultat (3 459). La forme
  initiale est reprise comme requête lente au L5.
