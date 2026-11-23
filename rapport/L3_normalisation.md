# 🗂️ L3 · Normalisation — Groupe 09

**Script de référence :** [`sql/04_normalisation_L3.sql`](sql/04_normalisation_L3.sql)  
**Captures d'appui :** A12 (dépendances fonctionnelles), A13 (redondance), A14 (dénormalisation)

---

## 1️⃣ La relation « à plat »

### Aperçu de BILLET_A_PLAT
Une ligne par billet, associé à sa séance (si elle existe), son spectateur et son site.

| 📊 Propriété | 📈 Valeur |
|---|---|
| **Nombre de lignes** | 378 407 (378 708 billets − 301 sur séance inexistante) |
| **Nombre de colonnes** | 24 |
| **Taille disque** | 80 Mo, 10 240 blocs de 8 Ko |
| **Clé primaire** | `id_billet` |

### Colonnes
**Billet :** id_billet, date_billet, nb_places, montant, statut  
**Groupe :** id_groupe  
**Spectateur :** id_spectateur, nom, prenom, email, telephone, ville_spectateur, id_cinema_rattachement, date_inscription  
**Séance :** id_seance, libelle, categorie, debut, duree_minutes, capacite, prix_unitaire  
**Cinéma :** id_cinema_seance, nom_cinema, ville_cinema

---

## 2️⃣ Dépendances fonctionnelles (vérifiées sur les données)

| 🔗 Dépendance | Violations | 📋 Type | 💬 Notes |
|---|---|---|---|
| **DF1** : id_billet → tous les attributs | 0 | ✅ Clé | C'est la clé primaire |
| **DF2** : id_spectateur → nom, prenom, email, … | 0 | ✅ Métier | Un spectateur = une identité unique |
| **DF3** : id_seance → libelle, categorie, début, … | 0 | ✅ Métier | Une séance = une programmation unique |
| **DF4** : id_cinema → nom_cinema, ville_cinema | 0 | ✅ Métier | Un cinéma = une localisation unique |
| **DF5** : ville_spectateur → id_cinema_rattachement | 0 | ⚠️ Coïncidence | Vraie dans les données, **mais pas une règle de gestion** |
| **DF6** : (nb_places, prix_unitaire) → montant | 28 | ⚠️ Partielle | Fausse pour 77 montants négatifs |
| **id_groupe → id_spectateur** | 9 | ❌ **Pas une DF** | 9 groupes ont plusieurs spectateurs |
| **id_groupe → date_billet** | 1 281 | ❌ **Pas une DF** | 1 281 groupes ont plusieurs dates |
| **email (minuscules) → id_spectateur** | 88 | ❌ **Pas une DF** | 88 doublons de personnes dans les fichiers |

**Comment lire** : Une dépendance X → Y est vérifiée en comptant les valeurs de X associées à plusieurs Y (voir annexe A12).

---

## 3️⃣ Forme normale de la relation à plat

### Analyse

✅ **1NF (Première Forme Normale)**  
Tous les attributs sont atomiques. ✓

✅ **2NF (Deuxième Forme Normale)**  
La clé `id_billet` est simple ; aucune dépendance partielle n'existe. ✓

❌ **Pas en 3NF (Troisième Forme Normale)**  
Il existe des dépendances transitives :
- `id_billet → id_seance → prix_unitaire, capacite, …`
- `id_billet → id_spectateur → nom, email, …`
- `id_seance → id_cinema → ville_cinema`

### Conséquences mesurées (annexe A13)

| 📊 Redondance | 🔢 Facteur | ⚠️ Impact |
|---|---|---|
| Chaque spectateur répété | **18,2 fois** en moyenne | Anomalies de modification |
| Chaque séance répétée | **50,3 fois** en moyenne | Anomalies de modification |
| Chaque site répété | **126 136 fois** | Redondance massive |

### Anomalies concrètes

**Problème de modification 🔧**  
Changer le prix d'une séance impose de modifier en moyenne 50 lignes dans BILLET_A_PLAT.

**Problème d'insertion ➕**  
Impossible d'enregistrer une séance sans billet, ou un spectateur sans achat.

**Problème de suppression ➖**  
Supprimer le dernier billet d'une séance fait disparaître toutes ses données (libellé, horaire, etc.).

---

## 4️⃣ Décomposition en 3NF (et BCNF)

Nous décomposons selon les dépendances métier **DF2, DF3, DF4** (théorème de Heath).

### Schéma normalisé

```sql
CINEMA (
  id_cinema, nom, ville, role
)

SPECTATEUR (
  id_spectateur, nom, prenom, email, telephone, ville, 
  date_inscription, #id_cinema
)

CATEGORIE (
  code_categorie, libelle
)

SEANCE (
  id_seance, libelle, #code_categorie, #id_cinema, 
  debut, duree_minutes, capacite, prix_unitaire
)

COMMANDE (
  id_commande, #id_spectateur_payeur, date_commande
)

BILLET (
  id_billet, #id_spectateur, #id_seance, #id_commande, 
  date_billet, nb_places, montant, statut
)
```

### Propriétés de cette décomposition

✅ **Sans perte** : chaque table est reliée à BILLET par la clé de sa DF.

✅ **Préservation des DF** : DF1 à DF4 sont portées chacune par une table.

✅ **BCNF (Forme Normale de Boyce-Codd)** : dans chaque table, le seul déterminant est la clé.

✅ **CATEGORIE séparée** : la liste des catégories est contrôlée par clé étrangère, garantissant l'intégrité.

---

## 5️⃣ Choix justifiés sur les dépendances particulières

### 🚫 DF5 : Non décomposée (ville_spectateur → id_cinema_rattachement)

**Raison :**  
Dans les fichiers, chaque spectateur est rattaché au site de sa ville — c'est une coïncidence, pas une règle.  
Rien n'interdit à un habitant de Metz de se rattacher au cinéma de Nancy.  
Créer une table VILLE → SITE figerait une contrainte fausse et rigidifierait le système.

### 💾 DF6 : Montant conservé malgré sa calculabilité

**Raison :**  
Le montant n'est **pas une redondance**, c'est une **valeur historique** :
- Il fige le prix payé au moment de l'achat
- Si le prix d'une séance change, les billets déjà vendus ne changent pas
- Il peut être réduit par une carte d'abonnement (RG9)

### 👥 id_groupe → spectateur/date : Non une DF

**Problème identifié :**  
- 9 groupes ont plusieurs spectateurs
- 1 281 groupes ont plusieurs dates

**Solution :**  
Création d'une entité `COMMANDE` avec un **payeur** et une date propre à chaque billet. Cela capture la réalité métier.

---

## 6️⃣ Dénormalisation assumée : `SEANCE.places_confirmees`

### La décision
Ajout d'une colonne **places_confirmees** dans SEANCE = somme des places des billets confirmés.

### 🤔 Pourquoi cette dénormalisation ?

**Règle métier RG10 :** Pas de sur-réservation — il faut vérifier à **chaque vente**.

**Coût sans places_confirmees :**  
Pour chaque vente, il faut additionner les billets de la séance (50 en moyenne, bien plus pour une avant-première complète).  
Le 11/02/2026 : **16 042 ventes** (C4) → 16 042 × 50 = **800 000+ opérations** au pic.

**Bénéfice avec places_confirmees :**  
- ✅ La vérification lit **une seule ligne**
- ✅ La ligne peut être verrouillée (`SELECT … FOR UPDATE`) pour éviter deux ventes simultanées de la dernière place

### 💪 Coût de maintenance

La valeur doit rester **cohérente** avec les billets :
- ✅ Calculée au chargement (volet 2)
- ✅ Maintenue par **trigger** à chaque insertion, annulation ou suppression de billet (volet 3)
- ✅ Contrôlée par une **requête de cohérence**

### 📄 Décision détaillée
Voir **ADR-01** pour le contexte complet de cette dénormalisation.
