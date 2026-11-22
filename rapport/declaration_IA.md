# Déclaration d'usage de l'IA — Groupe 09

À compléter au fil du projet.

| Outil | Pour quoi faire | Ce qui a été gardé | Ce qui a été corrigé |
|---|---|---|---|
| Claude (Anthropic) | analyse des défauts des CSV ; rédaction des scripts 00 à 02 ; requêtes C1 à C9 | requêtes C1 à C9, vérifiées par un calcul indépendant puis sous Oracle | voir ci-dessous |

## Cas où l'IA s'est trompée

1. **Script 00** : l'IA avait placé `ALTER SESSION SET CONTAINER = FREEPDB1` en tête du script.
   Détecté à l'exécution : SQL Developer a réinitialisé la session (« La base de données a été
   réinitialisée ») et le script s'est arrêté. Corrigé en supprimant la ligne.
2. **Script 00** : l'IA donnait les droits sur DBMS_RLS et DBMS_REDACT depuis SYSTEM.
   Détecté par l'erreur `ORA-01031: privilèges insuffisants`. Corrigé : script 00b exécuté en SYS.
3. **Analyse des données** : l'IA a annoncé un billet en double « 378260 » ; le bon identifiant est
   377260 (avec 377261). Détecté en relisant la sortie du script d'analyse.
