# 📔 Journal de bord — Groupe 09

## À propos de ce journal
Ce document rassemble l'historique du projet : les avancées, les décisions prises, les problèmes rencontrés et comment ils ont été résolus.

---

## 🗓️ Dimanche 20 novembre 2026

### Points d'arrivée
Nous avons reçu le sujet et les données du projet sous forme de fichier `donnees_groupe_09.zip`. Après analyse des fichiers CSV, nous avons identifié plusieurs défauts dans les données :
- Doublons de spectateurs avec e-mail en majuscules
- E-mails vides ou entourés d'espaces
- Billets associés à des séances inexistantes
- Montants négatifs
- Billets programmés après le début de la séance
- Billets en double
- Groupes avec plusieurs dates

### Décisions importantes
Nous avons décidé de **calculer les colonnes de vérification C1 à C9 sur des tables de chargement brutes** (nommées STG_*), sans effectuer de nettoyage préalable. Cela nous permettra d'avoir une vue claire de la qualité des données.

### Installation de l'environnement
✅ Oracle 26ai Free sous Docker  
✅ SQL Developer  
✅ Connexions aux bases BDD-system et BDD-club

### Création de l'utilisateur du projet CINE09
Nous avons lancé le script 00 de création. Deux problèmes rencontrés :

**❌ Problème 1 : Reconnexion incorrecte à la base**
```
Boîte de dialogue : "Reconnecter BDD-system — La base de données a été réinitialisée"
Cause : La commande ALTER SESSION SET CONTAINER = FREEPDB1 était exécutée alors que 
        la connexion était déjà sur FREEPDB1
✓ Solution : Suppression de cette ligne du script
```

**❌ Problème 2 : Privilèges insuffisants**
```
Erreur ORA-01031 sur : GRANT EXECUTE ON DBMS_RLS TO cine09
                       GRANT EXECUTE ON DBMS_REDACT TO cine09
Cause : Exécution avec l'utilisateur SYSTEM au lieu de SYS
✓ Solution : Création d'un script séparé (00b) exécuté en SYSDBA pour accorder ces droits
```

---

## 🗓️ Mardi 22 novembre 2026

### Résolution des problèmes techniques

**❌ Problème : Erreur de syntaxe Docker**
```
Erreur : SP2-0734: unknown command beginning "docker exe..."
Cause : La commande docker a été tapée directement dans SQL*Plus au lieu du terminal Windows
✓ Solution : Exécution dans le bon environnement (terminal Windows)
```

**❌ Problème : Fichiers CSV introuvables**
Les fichiers CSV étaient stockés dans un sous-dossier qui n'était pas au bon chemin d'accès.
```
✓ Solution : Déplacement dans /1-oracle-mysql/scripts/groupe_09
Vérification : docker exec oracle-bdd ls -l /scripts/groupe_09
```

### Chargement des données
✅ **Script 01** : Chargement par tables externes — Résultats conformes
- 4 lignes (spectateurs)
- 20 820 lignes (séances)
- 7 519 lignes (groupes)
- 378 708 lignes (billets)

✅ **Script 02** : Calcul des colonnes de vérification C1 à C9
- Résultats identiques au calcul de vérification indépendant ✓
- **Décision** : Utiliser le format de date `DD/MM/YYYY` pour C4 (l'affichage par défaut `11/02/26` était ambigu)

✅ **Captures** : Génération des captures A1 à A9

---

## 🗓️ Mercredi 23 novembre 2026

### Création du modèle de données

✅ **Script 03** : Création des 10 tables avec contraintes nommées
- Exécution sans erreur
- Contraintes clairement identifiées

✅ **Script 04** : Génération de la table à plat
- 378 407 lignes — 80 Mo — 10 240 blocs
- Dépendances fonctionnelles (DF) vérifiées

### Observations importantes

**Constat** : L'identifiant `id_groupe` ne détermine :
- ❌ Ni le payeur (un groupe peut avoir jusqu'à 9 payeurs différents)
- ❌ Ni la date (1 281 groupes ont plusieurs dates)

**Solution proposée** : Création d'une entité `COMMANDE` pour capturer le payeur.

### Schéma et dénormalisation
- ✅ Schéma entité-association généré avec **Mocodo**
  - Héritage XT des cartes
  - Association porteuse ACCES
  
- **Décision** : Dénormalisation de `SEANCE.places_confirmees` (ADR-01, version 1)
