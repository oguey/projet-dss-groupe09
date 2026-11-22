# Journal de bord — Groupe 09

Format : date · ce qui a été fait / décidé · erreur rencontrée (message exact) · résolution.

## 20/11/2026
- Réception du sujet et des données (`donnees_groupe_09.zip`). Analyse des CSV : défauts repérés
  (doublons de spectateurs par e-mail en majuscules, e-mails vides ou entourés d'espaces,
  billets sur séance inexistante, montants négatifs, billets postérieurs au début de la séance,
  billet en double, groupes à dates multiples).
- Décision : calculer C1 à C9 sur des tables de chargement brutes (STG_*), sans nettoyage préalable.
- Installation du kit : Oracle 26ai Free sous Docker, SQL Developer, connexions BDD-system et BDD-club.
- Création de l'utilisateur de projet CINE09 (script 00).
  - Erreur : boîte « Reconnecter BDD-system — La base de données a été réinitialisée » à l'exécution
    de `ALTER SESSION SET CONTAINER = FREEPDB1` (la connexion était déjà sur FREEPDB1).
    Résolution : ligne supprimée du script.
  - Erreur : `ORA-01031: privilèges insuffisants` sur `GRANT EXECUTE ON DBMS_RLS TO cine09` et
    `GRANT EXECUTE ON DBMS_REDACT TO cine09` exécutés en SYSTEM.
    Résolution : ces droits sont donnés par SYS dans un script séparé (00b), en SYSDBA.

## 22/11/2026
- Erreur : `SP2-0734: unknown command beginning "docker exe..."` : commande docker tapée dans sqlplus
  au lieu du terminal Windows.
- Les CSV étaient dans un sous-dossier non visible au bon chemin ; déplacés dans
  `1-oracle-mysql\scripts\groupe_09` (vérifié par `docker exec oracle-bdd ls -l /scripts/groupe_09`).
- Chargement par tables externes (script 01) : 4 / 20 820 / 7 519 / 378 708 lignes, conformes aux fichiers.
- C1 à C9 calculées (script 02), identiques au calcul de vérification indépendant.
  Décision : format de date `DD/MM/YYYY` pour C4 (l'affichage par défaut `11/02/26` était ambigu).
- Captures A1 à A9 réalisées.
