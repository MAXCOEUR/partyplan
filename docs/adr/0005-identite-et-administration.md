# ADR 0005 — Identité : mot de passe et administration de plateforme

- Date : 19/08/2026
- Statut : accepté
- Révise : hypothèse `HY-01` du cahier des charges

## Contexte

Le cahier des charges posait initialement une authentification sans mot de passe (lien
magique et connexions tierces). Le commanditaire demande, dès le départ, une gestion
complète des comptes : modification, suppression, photo de profil, ainsi qu'un compte
administrateur amorcé par variables d'environnement disposant d'une liste des
utilisateurs, avec suppression et réinitialisation de mot de passe.

Un back-office capable de « réinitialiser un mot de passe » suppose qu'un mot de passe
existe.

## Décision

1. Authentification par adresse e-mail et mot de passe, complétée par Google puis Apple.
2. Le lien à usage unique n'est pas supprimé : il devient le véhicule de la vérification
   d'adresse et de la réinitialisation. Un seul mécanisme de jeton sert les deux besoins.
3. Deux axes de rôle indépendants : `users.platform_role`
   (`User` · `Support` · `PlatformAdmin`) et `event_members.role`
   (`Member` · `Admin` · `Owner`).
4. Le premier `PlatformAdmin` est amorcé au démarrage depuis `ADMIN_EMAIL` et
   `ADMIN_PASSWORD`, de façon idempotente.
5. Le back-office vit sous les routes `/admin/*` de l'application Web, absentes des
   applications mobiles.
6. L'identité est développée avant toute fonctionnalité événementielle : version V0.5 de
   la feuille de route.

## Contreparties assumées

Le mot de passe réintroduit une surface que le lien magique évitait. Elle est traitée,
et non ignorée :

| Risque réintroduit | Traitement |
|---|---|
| Mot de passe faible ou réutilisé | 12 caractères minimum, refus des mots de passe compromis, aucune expiration périodique — `RG-AUTH-01`, conforme aux recommandations ANSSI et CNIL |
| Fuite de la base | Argon2id — `RG-AUTH-02` |
| Force brute | Ralentissement croissant après dix échecs, sans verrouillage définitif — `RG-AUTH-05` |
| Énumération de comptes | Réponse identique que l'adresse existe ou non — `RG-AUTH-04` |
| Compromission d'un compte administrateur | Double authentification obligatoire pour tout rôle plateforme — `RG-ADM-04` |
| Identifiant par défaut laissé en production | Refus de démarrage si l'amorçage est incomplet ou le mot de passe faible — `RG-ADM-11` |

## Règles structurantes

**Un rôle plateforme ne donne aucun accès au contenu d'un événement** — `RG-ADM-01`.
Ni membres, ni dépenses, ni courses, ni discussion. Un `PlatformAdmin` non membre reçoit
404, exactement comme un tiers. C'est la condition pour que la promesse d'événement privé
du `RG-EVT-01` soit vraie, et non déclarative. Aucune exception « pour le support » ne
sera ajoutée : le support agit sur des comptes, pas sur des contenus.

**Un administrateur ne détient jamais un mot de passe** — `RG-ADM-02`. Il déclenche
l'envoi d'un lien de réinitialisation à l'adresse enregistrée, sans jamais choisir ni
consulter la valeur.

**Le journal d'audit est en ajout seul** — `RG-ADM-06`, `NF-SEC-08`. Le rôle applicatif
ne dispose ni de `UPDATE` ni de `DELETE` sur la table. Un administrateur ne peut pas
effacer la trace de ses propres actions.

**Séparation `Support` / `PlatformAdmin`** — `RG-ADM-05`. Traiter la demande d'un
utilisateur ne nécessite pas le droit de supprimer un compte.

## Conséquences

- Trois tables ajoutées : `admin_audit_entries`, `password_reset_tokens`,
  `email_verification_tokens`. La table `magic_links` disparaît, remplacée par les deux
  dernières.
- La table `users` porte le hachage, le rôle plateforme, l'état de vérification, l'état
  de suspension et le secret TOTP chiffré.
- L'accès administratif devient un traitement au sens du RGPD : base légale, durée de
  conservation du journal, et description dans la politique de confidentialité —
  `RG-RGPD-04`.
- Le développement de l'identité précède celui des événements, ce qui retarde la
  première démonstration fonctionnelle mais évite de greffer l'authentification sur des
  fonctionnalités déjà écrites.
