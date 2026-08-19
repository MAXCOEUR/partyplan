# Feuille de route PartyPlan — tout ce qui reste à faire

> Document unique de suivi. Chaque ligne est une tâche à cocher.
> Les références `EF-`, `RG-`, `NF-` renvoient au [cahier des charges](cahier-des-charges.md),
> où la règle précise est écrite. Ne rien ajouter ici sans référence : si une tâche
> n'existe pas dans le cahier des charges, c'est le cahier des charges qu'il faut
> compléter d'abord.

Mise à jour : 19/08/2026 — V0 livrée hors lots 0.1 et 0.7

## Comment lire ce document

| Version | Contenu | Cible de publication |
|---|---|---|
| **V0** | Socle technique et environnement local. Rien de visible. | interne |
| **V0.5** | **Comptes et administration.** Développé en premier : inscription, profil, photo, sessions, administrateur amorcé, back-office, journal d'audit. | interne |
| **V1.0** | MVP événementiel : présence, courses, dépenses, remboursements, planning. | PWA + Google Play |
| **V1.1** | Collaboration : tâches, sondages, discussion, groupes. | PWA + Google Play |
| **V1.2** | Portage iOS. | App Store |
| **V2.0** | Offre Premium et modèles d'événements. | toutes plateformes |
| **V2.1** | IA, statistiques, intégrations système. | toutes plateformes |

Règle de progression : une version ne s'ouvre que lorsque la précédente est publiée.
Toute tâche non cochée d'une version publiée devient une anomalie, pas un report.

---

## Avancement

| Version | Tâches faites | Reste |
|---|---|---|
| V0 — socle technique | lots 0.2 à 0.6 | lot 0.1 (démarches), lot 0.7 (serveur) |
| V0.5 — comptes et administration | — | tout |
| V1.0 — MVP événementiel | — | tout |

Décisions d'architecture prises : `ADR 0001` monorepo, `ADR 0002` monolithe modulaire,
`ADR 0003` domaines et certificats, `ADR 0004` chaîne de livraison, `ADR 0005` identité
et administration.

---

# V0 — Socle technique

Objectif : une application vide mais déployée, une base migrée, une CI verte.
Sortie : les trois domaines répondent en HTTPS.

**État au 19/08/2026 : lots 0.2 à 0.6 livrés et vérifiés en local.** Restent le lot 0.1
(démarches et arbitrages qui n'appartiennent qu'au commanditaire) et le lot 0.7
(serveur à provisionner). Le détail des vérifications figure en fin de section.

## Lot 0.1 — Identité et préalables

Aucune de ces tâches ne peut être faite à ma place : elles supposent un compte, un
paiement ou un arbitrage.

- [ ] Vérifier la disponibilité du nom « PartyPlan » à l'INPI, classes 9 et 42
- [ ] Vérifier la disponibilité du domaine `partyplan.fr` et le réserver si libre
- [ ] Arbitrer le nom définitif (PartyPlan, SoiréeSync, BringIt, WhoBrings, Planzy, ChillPlan, Gatherly)
- [ ] Fournir le logo en source vectorielle, puis exporter : SVG, PNG 1024, favicon, icône adaptative Android, icône iOS
- [ ] Remplacer les icônes par défaut de Flutter par celles de PartyPlan
- [ ] Choisir l'hébergeur, situé dans l'Union européenne — `RG-RGPD-03`
- [ ] Créer les enregistrements DNS : `partyplan`, `api.partyplan`, `cdn.partyplan`
- [ ] Créer le dépôt GitHub distant et pousser le monorepo
- [ ] Configurer la protection de la branche `main` (revue obligatoire, CI verte)

## Lot 0.2 — Outillage du dépôt

- [x] `.editorconfig` : conventions C# et Dart, nommage, style
- [x] Modèle de pull request rappelant les règles non négociables — `.github/pull_request_template.md`
- [x] `NF-SEC-05` Analyse des vulnérabilités en CI, transitives incluses, blocage sur gravité élevée ou critique
- [x] `ADR 0002` Contrôle automatisé des frontières de modules — `tools/verifier-frontieres-modules.sh`, exécuté en CI
- [x] Contrôle CI de format : `dotnet format --verify-no-changes` et `dart format --set-exit-if-changed`
- [x] `NF-OPS-08` Interdiction de construire une image sur le serveur — `ADR 0004` et `docs/exploitation.md` §6
- [x] `NF-OPS-09` Contrôle que tout secret figure dans les `.env.example` — par revue, via le modèle de pull request
- [ ] Automatiser `NF-OPS-09` : comparer les clés lues par le code aux clés déclarées dans les `.env.example`

## Lot 0.2b — Environnement de développement local

Contrainte permanente : tout doit tourner en local avant d'être poussé — `§13.4`.

- [x] `NF-DEV-01` Démarrage de la pile en une commande (`make up`)
- [x] `NF-DEV-02` Aucun service externe requis : Poppins embarquée, courriels capturés, connexions tierces vides
- [x] `NF-DEV-03` Capture des courriels par Mailpit, interface sur `localhost:8025`
- [x] `NF-DEV-07` Outil de jeu de données de démonstration, idempotent — `api/tools/PartyPlan.Seed`
  - → dépenses et remboursements de démonstration reportés au lot 1.8 : écrire ici un
    second calcul de répartition créerait une deuxième source de vérité sur la règle
    la plus sensible du produit (`§6.2`)
- [x] `NF-DEV-08` Migrations locales identiques à celles de la production, appliquées au démarrage
- [x] `NF-DEV-09` Rechargement à chaud vérifié : `dotnet watch` (14 projets chargés, API à 200) et `flutter run`
- [x] `RG-DEV-01` Refus de démarrage sur valeur de commodité en `Production` — vérifié, y compris dans le conteneur
- [x] `RG-DEV-02` `.env.example` comme documentation de référence des variables
- [x] `RG-DEV-03` Interdiction d'accéder à la base de production depuis un poste — `docs/exploitation.md` §6
- [x] Contrôle avant push : `make verif` (format, analyse, frontières, tests)
- [ ] `NF-DEV-04` Journaliser les notifications poussées en console faute de clé — arrive avec le lot 1.11, aucun émetteur n'existe encore
- [ ] `NF-DEV-05` Vérifier que l'inscription fonctionne sans clé Google — vérifiable au lot 0.8, aucun endpoint d'authentification n'existe encore
- [ ] `NF-DEV-06` Amorcer effectivement l'administrateur de développement — lot 0.11 ; les identifiants sont déjà documentés et la garde en place
- [ ] `NF-DEV-10` Vérifier `make test` réseau coupé — non vérifié : suppose de désactiver le réseau et d'avoir l'image PostgreSQL en cache local

## Lot 0.3 — API, squelette

- [x] Solution `api/PartyPlan.slnx` — 17 projets
- [x] `PartyPlan.Api` (hôte), `PartyPlan.SharedKernel`, `PartyPlan.Infrastructure`
- [x] Onze modules : `Auth`, `Users`, `Events`, `Shopping`, `Expenses`, `Settlements`, `Tasks`, `Polls`, `Messages`, `Notifications`, `Administration`
- [x] Projets de tests unitaires et d'intégration, plus l'outil de jeu de données
- [x] Découverte et enregistrement des modules, ordre déterministe — `ModuleRegistry`
- [x] `§8.1` Erreurs au format RFC 9457, avec identifiant de corrélation dans le corps
- [x] `NF-OPS-02` Journalisation JSON structurée avec identifiant de corrélation par requête
- [x] `NF-OPS-01` `/health/live` et `/health/ready`, ce dernier vérifiant la base
- [x] Contrat OpenAPI publié sur `/openapi/v1.json` et versionné dans `docs/api/openapi.json`
- [x] `NF-SEC-04` Limitation de débit : politique globale, plus deux politiques nommées pour `RG-INV-03` et `RG-AUTH-05`
- [x] Authentification par jeton porteur et politiques d'autorisation des rôles plateforme
- [x] `NF-SEC-01` En-têtes de sécurité sur toute réponse de l'API, `X-Robots-Tag` compris
- [x] Image Docker de l'API construite (247 Mo) et démarrage vérifié
- [ ] `§8.1` Filtre d'idempotence sur les créations — la table `idempotency_keys` et l'entité existent, le filtre HTTP reste à écrire (nécessaire au lot 1.7)

## Lot 0.4 — Base de données

- [x] `DbContext` unique, EF Core 10 et Npgsql, implémentant les onze contrats de module
- [x] Entités des **27 tables** du `§7.2`
- [x] `§6.1` `numeric(10,2)` sur tous les montants, `decimal` en C#, aucun flottant — vérifié par test
- [x] `§7.1` Identifiants `uuid` v7, attribués à l'écriture
- [x] `citext` sur `users.email` et les autres colonnes d'adresse
- [x] Convention `snake_case` sur tables, colonnes, clés et index
- [x] Migration initiale, plus une migration de déclencheurs d'ajout seul
- [x] `§13.3` Migrations appliquées au démarrage de l'API
- [x] `RG-SEC-01`, `RG-SEC-02` Filtre global de cloisonnement, appliqué par le contexte et non par requête
- [x] Contraintes de contrôle en base : montant positif et plafonné, parts strictement positives, remboursement entre membres distincts
- [x] `NF-SEC-08` Ajout seul sur `admin_audit_entries`, `activity_entries`, `expense_revisions` : garde applicatif et déclencheur couvrant `UPDATE`, `DELETE` et `TRUNCATE`
- [x] Index du `§7.2`, dont les index partiels d'unicité (adresse d'un compte vivant, code court non archivé, propriétaire unique)
- [x] Tests d'intégration sur base PostgreSQL réelle, via Testcontainers

## Lot 0.5 — Flutter, squelette

- [x] Projet `app/` : Android, iOS, Web
- [x] Gestion d'état : Riverpod
- [x] Routage `go_router`, avec route profonde `/join/:token` vérifiée en accès direct
- [x] Stockage sécurisé du jeton de session, distinguant compte et invité sans compte
- [x] Client HTTP unique avec injection du jeton, en-tête d'idempotence et traduction des erreurs RFC 9457
- [x] États génériques de chargement, d'erreur et de vide
- [x] Manifeste PWA, `index.html` en `noindex`, service worker Flutter
- [x] Script de génération du client Dart depuis l'OpenAPI — `tools/generate-api-client.sh`
- [x] Image Docker web construite (80 Mo), route profonde et en-têtes de sécurité vérifiés en service
- [ ] Rafraîchissement automatique de session à l'expiration du jeton — lot 0.8, aucun endpoint de rafraîchissement n'existe
- [ ] Générer effectivement le client Dart — lot 0.8, le contrat ne décrit qu'un endpoint

## Lot 0.6 — Design system Flutter

- [x] Poppins embarquée en quatre graisses, licence incluse — aucun téléchargement à l'exécution
- [x] Jetons de design : couleurs de la charte, espacements, rayons, durées, ombre unique
- [x] Thèmes clair et sombre complets
- [x] Composants : carte, étiquette, avatar, pile d'avatars, pastille de statut, barre de progression, états vide, erreur et chargement
- [x] Deux composants signature : `PpMoney` (chiffres tabulaires, couleur porteuse de sens, espace insécable) et `PpClaimChip` (contour → aplat avec visage)
- [x] `RG-UI-01` Barre de navigation inférieure à cinq entrées
- [x] `RG-UI-03` Écriture optimiste avec retour arrière visible — `PpOptimisticAction`
- [x] `NF-A11Y-01` Contrastes WCAG AA vérifiés par test automatisé
  - → cinq combinaisons de la charte échouaient : variantes assombries ajoutées pour le
    texte sur fond clair, couleurs de charte conservées sur fond sombre et pour les aplats
- [x] `NF-A11Y-02` Cibles tactiles de 44 points, vérifiées par test
- [x] `NF-A11Y-03` Libellés sémantiques sur les composants, dont une phrase lisible pour les montants
- [x] `NF-I18N-01` Chaînes regroupées dans `PpStrings`, aucune en dur dans un écran
- [ ] Migrer `PpStrings` vers des fichiers ARB traduits — à faire avant toute langue supplémentaire

## Lot 0.7 — Déploiement initial

- [x] Documenter la procédure de déploiement, de retour arrière, de sauvegarde et de restauration — `docs/exploitation.md`
- [ ] Provisionner le serveur
- [ ] Installer Docker et Compose
- [ ] Déployer la pile `compose.example.yml`
- [ ] Vérifier l'obtention des certificats sur les trois domaines
- [ ] `NF-SEC-01` Vérifier HSTS et les en-têtes en production
- [ ] Brancher la copie des sauvegardes hors du serveur — une sauvegarde restée sur la machine ne protège pas de sa perte

## Vérifications exécutées le 19/08/2026

| Contrôle | Résultat |
|---|---|
| `dotnet build` sur 17 projets | 0 erreur, 0 avertissement (avertissements traités en erreurs) |
| Tests unitaires | 36 réussis |
| Tests d'intégration, PostgreSQL réel | 18 réussis |
| Tests Flutter | 38 réussis |
| `flutter analyze` | aucun problème |
| `dotnet format --verify-no-changes` | conforme |
| `dart format --set-exit-if-changed` | conforme |
| Frontières de modules | 11 modules, aucune violation |
| Migration appliquée sur PostgreSQL 16 | 27 tables, 4 contraintes de contrôle |
| Journal d'audit | `UPDATE`, `DELETE` et `TRUNCATE` refusés, ligne intacte |
| Cloisonnement | membre 200, non-membre 404, `PlatformAdmin` non membre 404, anonyme 401, invité limité à son événement |
| Garde de production | démarrage refusé sans secrets, en local comme en conteneur |
| Images Docker | API 247 Mo, web 80 Mo, vitrine 48 Mo |
| Application web servie | racine et route profonde à 200, en-têtes de sécurité présents |

## Écarts constatés par rapport au plan initial

| Point | Écart | Motif |
|---|---|---|
| Nombre de tables | 27 au lieu de 20 | Le `§7.2` ne détaillait pas `expense_revisions`, `event_mute_settings`, `push_devices`, `idempotency_keys` ni les tables de jetons. Le cahier des charges a été complété. |
| Modules | 11 au lieu de 10 | Module `Administration` ajouté par l'`ADR 0005`. |
| Contrat OpenAPI | `/openapi/v1.json` | Le document est versionné : `/openapi.json` ne l'aurait pas été. |
| Solution | `PartyPlan.slnx` | Format par défaut du SDK .NET 10. |
| Port PostgreSQL local | 5433 | 5432 est occupé par un autre projet sur le poste. |
| Accessibilité | Variantes de couleur ajoutées | Cinq combinaisons de la charte échouaient au seuil AA. |
| Taille du bundle web | 31 Mo | Rendu CanvasKit par défaut. À mesurer contre `NF-PERF-04` (2,5 s en 4G) avant la bêta. |

---

# V0.5 — Comptes et administration

Objectif : l'identité est intégralement gérée avant qu'une seule fonctionnalité
événementielle n'existe. Un utilisateur crée son compte, le modifie, le supprime ;
un administrateur gère les comptes sans jamais voir le contenu d'un événement.
Sortie : les critères 1 à 12 du `§18` sont vérifiés en local.

## Lot 0.8 — Authentification par mot de passe

- [ ] `EF-AUTH-01` Inscription par adresse e-mail et mot de passe
- [ ] `RG-AUTH-01` 12 caractères minimum, refus des mots de passe compromis, aucune expiration périodique
- [ ] `RG-AUTH-02` Hachage Argon2id, jamais de mot de passe journalisé ni consultable
- [ ] `EF-AUTH-02` Connexion par adresse e-mail et mot de passe
- [ ] `EF-AUTH-03` Vérification de l'adresse e-mail par lien
- [ ] `EF-AUTH-04` Réinitialisation du mot de passe par lien
- [ ] `RG-AUTH-03` Liens valables 15 minutes, usage unique, condensé seul stocké
- [ ] `RG-AUTH-04` Réponse identique que l'adresse existe ou non
- [ ] `EF-AUTH-05` Changement de mot de passe avec l'ancien
- [ ] `RG-AUTH-05` Cinq demandes par heure, ralentissement croissant après dix échecs, aucun verrouillage définitif
- [ ] `RG-AUTH-06` Révocation des autres sessions à la réinitialisation et au changement d'adresse
- [ ] `EF-AUTH-09` Session de 90 jours, prolongée à l'usage
- [ ] `EF-AUTH-10` Liste des sessions actives, révocation d'une session ou de toutes
- [ ] Écrans : inscription, connexion, mot de passe oublié, réinitialisation, sessions

## Lot 0.9 — Connexions tierces et double authentification

- [ ] `EF-AUTH-06` Connexion Google
- [ ] `EF-AUTH-08` Rattachement et détachement d'une connexion tierce
- [ ] `RG-AUTH-08` Un compte sans mot de passe peut en définir un par le parcours de réinitialisation
- [ ] `EF-AUTH-12` Double authentification par code temporel (TOTP) : enrôlement, activation, désactivation
- [ ] `NF-DEV-05` Fonctionnement complet sans aucune clé Google configurée
- [ ] Écrans : rattachement des connexions, enrôlement TOTP avec QR code

## Lot 0.10 — Compte et profil

- [ ] `EF-USR-01` Consultation du profil
- [ ] `EF-USR-02` Modification du nom affiché
- [ ] `RG-USR-04` Historique du nom conservé sur les événements en cours et dans le fil d'activité
- [ ] `EF-USR-03` Changement d'adresse e-mail avec vérification préalable
- [ ] `EF-USR-04` Téléversement d'une photo de profil
- [ ] `RG-USR-01` JPEG, PNG, WebP, HEIC, 5 Mo maximum, trois tailles, conversion WebP, suppression des EXIF
- [ ] `NF-SEC-09` Type MIME vérifié par le contenu, taille plafonnée
- [ ] `EF-USR-05` Recadrage avant envoi
- [ ] `EF-USR-06` Suppression de la photo et retour à l'avatar par défaut
- [ ] `RG-USR-02` Avatar par défaut généré localement à partir des initiales, sans service externe
- [ ] `RG-USR-03` Photos servies par le domaine statique, adresse contenant une empreinte du contenu
- [ ] `EF-USR-07` Choix de la langue et du fuseau horaire
- [ ] `EF-USR-08` Préférences de notification
- [ ] `EF-USR-09` Export de toutes ses données au format JSON
- [ ] `EF-USR-10` Suppression de son compte depuis l'application
- [ ] `RG-USR-05` Anonymisation financière expliquée avant confirmation, confirmation par saisie de l'adresse
- [ ] `RG-USR-06` Un compte supprimé libère son adresse e-mail
- [ ] Écrans : profil, édition du profil, photo, sécurité, sessions, confidentialité

## Lot 0.11 — Amorçage de l'administrateur

- [ ] `EF-ADM-01` Création du compte administrateur au démarrage depuis l'environnement
- [ ] `RG-ADM-09` Opération idempotente, mot de passe d'amorçage jamais réappliqué
- [ ] `RG-ADM-10` Changement de mot de passe et activation TOTP imposés à la première connexion
- [ ] `RG-ADM-11` Refus de démarrer en production si l'amorçage est incomplet ou le mot de passe faible
- [ ] `RG-ADM-12` Avertissement au démarrage si `ADMIN_PASSWORD` reste présent après changement
- [ ] Test : base vierge puis second démarrage, aucun doublon

## Lot 0.12 — Back-office d'administration

- [ ] `EF-ADM-02` Liste des comptes : recherche par nom ou adresse, tri, pagination
- [ ] `EF-ADM-03` Fiche technique d'un compte
- [ ] `EF-ADM-04` Déclenchement d'une réinitialisation de mot de passe
- [ ] `RG-ADM-02` Un administrateur ne définit, ne consulte, ni ne transmet jamais un mot de passe
- [ ] `EF-ADM-05` Révocation de toutes les sessions d'un utilisateur
- [ ] `EF-ADM-06` Suspension avec motif, et réactivation
- [ ] `RG-ADM-07` Un compte suspendu ne peut plus se connecter, sessions révoquées, données intactes
- [ ] `EF-ADM-07` Suppression d'un compte, avec la même anonymisation que l'auto-suppression
- [ ] `EF-ADM-08` Promotion et révocation des rôles `Support` et `PlatformAdmin`
- [ ] `RG-ADM-03` Interdiction de se supprimer, de se révoquer, ou de supprimer le dernier administrateur
- [ ] `RG-ADM-04` Double authentification obligatoire pour tout rôle plateforme, promotion refusée sinon
- [ ] `RG-ADM-05` Le rôle `Support` limité à cinq actions de consultation et de dépannage
- [ ] `EF-ADM-09` Consultation du journal d'audit
- [ ] `EF-ADM-10` Indicateurs d'instance : comptes, événements actifs, invités, stockage
- [ ] `RG-ADM-08` Écrans d'administration absents des applications mobiles, routes `/admin/*` en Web seulement
- [ ] Écrans : liste des comptes, fiche de compte, journal d'audit, indicateurs

## Lot 0.13 — Cloisonnement et audit

- [ ] `RG-ADM-01` **Aucun rôle plateforme ne donne accès au contenu d'un événement**
- [ ] Test d'intégration : un `PlatformAdmin` non membre reçoit 404 sur chaque endpoint d'événement
- [ ] Test d'intégration : un `User` puis un `Support` sur chaque endpoint `/v1/admin/*`
- [ ] `RG-ADM-06` Journal d'audit immuable : auteur, cible, action, motif, horodatage, adresse IP
- [ ] `NF-SEC-08` Retirer les droits `UPDATE` et `DELETE` sur la table d'audit au rôle applicatif
- [ ] `RG-RGPD-04` Décrire dans la politique de confidentialité le périmètre d'accès du support
- [ ] `NF-SEC-06` Vérifier Argon2id et le refus des mots de passe compromis
- [ ] `NF-SEC-07` Vérifier l'obligation de double authentification des rôles plateforme

## Lot 0.14 — Recette V0.5

- [ ] Vérifier les critères 1 à 12 du `§18`
- [ ] `EF-ADM-11` Forcer la vérification d'une adresse en cas de courriel non délivré *(P1, peut glisser)*
- [ ] `EF-ADM-12` Export des données d'un utilisateur ne pouvant plus se connecter *(P1)*
- [ ] `EF-ADM-13` Suppression d'une photo de profil signalée *(P1)*

---

# V1.0 — MVP événementiel

Objectif : le parcours complet « créer une soirée → inviter → répondre → courses →
prix → remboursements » fonctionne en production.
Sortie : les critères 13 à 26 du `§18` sont vérifiés.

## Lot 1.1 — Rattachement des invités sans compte

- [ ] `EF-AUTH-11` Conversion d'une participation d'invité en compte permanent
- [ ] `RG-AUTH-07` Liaison sur le jeton de session invité, jamais sur le prénom
- [ ] Test : aucun doublon de membre après conversion, dépenses conservées

## Lot 1.2 — Événements

- [ ] `EF-EVT-01` Créer un événement : nom, date, heure, lieu, description
- [ ] `EF-EVT-02` Date de fin facultative, sinon fin implicite à +12 heures
- [ ] `EF-EVT-03` Modifier l'événement, avec notification en cas de changement de date ou de lieu
- [ ] `EF-EVT-04` Tableau de bord de l'événement
- [ ] `RG-UI-02` Le tableau de bord affiche l'information actionnable du moment
- [ ] `EF-EVT-05` Liste « à venir » et « passés »
- [ ] `EF-EVT-06` Quitter un événement
- [ ] `RG-ROLE-02` Le propriétaire doit transférer la propriété avant de quitter
- [ ] `EF-EVT-07` Supprimer un événement, avec confirmation explicite
- [ ] `RG-EVT-02` Blocage de la suppression si des règlements restent en attente
- [ ] `RG-EVT-01` En-tête `noindex` sur toute page d'événement
- [ ] Gestion des rôles `Owner` / `Admin` / `Member` — `RG-ROLE-01`
- [ ] `RG-ROLE-03` L'exclusion d'un membre préserve ses données financières
- [ ] Écrans : accueil, création d'événement, tableau de bord, paramètres de l'événement

## Lot 1.3 — Invitations et accès sans compte

- [ ] `EF-INV-01` Lien d'invitation `/join/{token}`
- [ ] `RG-INV-01` Jeton de 128 bits minimum, non déductible de l'identifiant
- [ ] `EF-INV-02` QR code exportable en image
- [ ] `EF-INV-03` Code court `PLAN-XXXXXX`
- [ ] `RG-INV-02` Alphabet de 32 caractères sans ambiguïté, 6 positions, unicité
- [ ] `RG-INV-03` Limitation à 10 résolutions par minute et par IP, 100 par jour
- [ ] `RG-INV-04` Aperçu restreint avant participation : nom, date, lieu, nombre
- [ ] `EF-INV-04` Rejoindre avec un prénom seulement, sans compte
- [ ] `RG-INV-05` Parcours en deux écrans maximum
- [ ] `EF-INV-05` Régénérer le lien, ce qui invalide le précédent
- [ ] `EF-INV-06` Fermer les nouvelles arrivées
- [ ] Écrans : aperçu d'invitation, saisie du prénom, choix du statut
- [ ] Recette : trois interactions maximum depuis un navigateur sans session

## Lot 1.4 — Présences

- [ ] `EF-PRES-01` Cinq statuts : présent, peut-être, absent, arrive plus tard, part plus tôt
- [ ] `EF-PRES-02` Heure d'arrivée et de départ prévues
- [ ] `EF-PRES-03` Modification du statut à tout moment
- [ ] `EF-PRES-04` Liste des membres avec statut et horaires
- [ ] `EF-PRES-05` Synthèse « n confirmés sur m invités »
- [ ] `RG-PRES-01` Statut initial `Unknown`, jamais présumé présent
- [ ] `RG-PRES-02` `Late` et `EarlyLeave` comptent comme présents
- [ ] `RG-PRES-03` `Maybe` compté séparément
- [ ] Écran : invités

## Lot 1.5 — Liste de courses

- [ ] `EF-CRS-01` Ajouter un article : libellé, quantité, unité, catégorie
- [ ] `EF-CRS-02` Quatre catégories : boissons, nourriture, matériel, autres
- [ ] `EF-CRS-03` S'attribuer un article
- [ ] `RG-CRS-01` Attribution unique, contrôlée en transaction côté serveur
- [ ] `EF-CRS-04` Retirer son attribution
- [ ] `EF-CRS-05` Marquer acheté avec quantité réellement obtenue
- [ ] `RG-CRS-02` Affichage du reliquat en cas d'achat partiel
- [ ] `EF-CRS-06` Prix estimé et prix réellement payé
- [ ] `EF-CRS-07` Création automatique d'une dépense à la saisie du prix payé
- [ ] `RG-CRS-03` Le prix estimé n'entre jamais dans les calculs
- [ ] `EF-CRS-08` Modifier et supprimer un article, refus si une dépense y est rattachée
- [ ] `EF-CRS-09` Avancement « n / m pris » et « n / m achetés »
- [ ] `EF-CRS-10` Commentaire sur un article
- [ ] Test de concurrence : deux attributions simultanées, une seule aboutit
- [ ] Écran : courses

## Lot 1.6 — Temps réel

- [ ] Exposer le hub SignalR sur `/hubs/event` — `RG-RT-01`
- [ ] Contrôler l'appartenance à l'événement à l'établissement de la connexion
- [ ] Diffuser les 18 messages du `§9`
- [ ] `RG-RT-02` Chaque message porte l'état résultant, pas seulement un identifiant
- [ ] `RG-RT-03` Rechargement complet de l'écran actif à la reconnexion
- [ ] Client Flutter : abonnement, reconnexion, application des messages à l'état local
- [ ] Recette : propagation en moins d'une seconde — `NF-PERF-05`
- [ ] `RG-RT-04` Rester en instance unique : tout ajout d'une seconde instance impose Redis et un ADR préalable

## Lot 1.7 — Dépenses

- [ ] `EF-DEP-01` Créer une dépense : libellé, montant, payeur, date
- [ ] `RG-DEP-01` Montant strictement positif, plafonné à 99 999,99 €
- [ ] `EF-DEP-02` Trois modes d'assiette : tous les présents, sélection, parts personnalisées
- [ ] `RG-DEP-02` Assiette figée à la création, sans effet rétroactif
- [ ] `RG-DEP-03` Possibilité d'exclure le payeur de l'assiette
- [ ] `EF-DEP-03` Modifier et supprimer une dépense
- [ ] `RG-DEP-04` Historique des modifications conservé
- [ ] `RG-DEP-05` Suppression logique, avec recalcul des soldes
- [ ] `EF-DEP-04` Liste des dépenses avec totaux
- [ ] `EF-DEP-05` Détail d'une dépense : payeur, participants, part de chacun
- [ ] Écrans : dépenses, création de dépense, détail

## Lot 1.8 — Remboursements

- [ ] `§6.2` Répartition au centime avec la règle des plus grands restes
- [ ] `IV-01` Vérifier que la somme des parts égale exactement le montant
- [ ] `§6.3` Calcul des soldes
- [ ] `IV-02` Vérifier que la somme des soldes est nulle, journaliser toute violation
- [ ] `§6.4` Algorithme d'appariement glouton, tri déterministe des égalités
- [ ] `RG-RMB-01` Résultat reproductible à l'identique
- [ ] `RG-RMB-02` Aucun solde persisté, recalcul à la demande
- [ ] `RG-RMB-03` Les règlements effectués entrent dans le calcul suivant
- [ ] `EF-RMB-01` Affichage du solde de chaque membre
- [ ] `EF-RMB-02` Liste des règlements proposés
- [ ] `RG-CALC-01` Ordre d'affichage identique à l'ordre d'émission
- [ ] `EF-RMB-03` Marquer un règlement comme effectué
- [ ] `EF-RMB-04` Annuler un marquage
- [ ] `EF-RMB-05` Rappel de sa propre dette sur le tableau de bord
- [ ] `RG-RMB-04` Avertissement si la somme des soldes n'est pas nulle
- [ ] **Test bloquant** : le jeu de référence du `§6.5` produit les deux règlements attendus, dans l'ordre attendu
- [ ] `RG-TEST-02` Test de l'invariant `IV-02` sur données générées aléatoirement
- [ ] `NF-QUAL-01` Couverture de 100 % des branches du domaine financier
- [ ] `RG-TEST-01` Interdire toute livraison du domaine financier sans passage du jeu de référence
- [ ] `NF-PERF-03` Calcul complet en moins de 50 ms pour 20 membres et 100 dépenses
- [ ] Écran : règlements

## Lot 1.9 — Planning

- [ ] `EF-PLN-01` Créer une étape : heure, libellé, lieu, commentaire
- [ ] `EF-PLN-02` Liste chronologique
- [ ] `EF-PLN-03` Modifier et supprimer une étape
- [ ] `EF-PLN-04` Mise en évidence de la prochaine étape sur le tableau de bord
- [ ] Écran : planning

## Lot 1.10 — Fil d'activité

- [ ] `EF-FIL-01` Fil horodaté des actions structurantes
- [ ] `RG-FIL-01` Couvrir les 10 catégories d'événements listées
- [ ] `RG-FIL-02` Lecture seule, non modifiable même par le propriétaire
- [ ] Pagination par curseur — `§8.1`
- [ ] Intégration au tableau de bord

## Lot 1.11 — Notifications

- [ ] Configurer les notifications poussées (Firebase) pour Android et Web
- [ ] `EF-NOT-01` Réponses aux invitations, à l'organisateur
- [ ] `EF-NOT-02` Modification de date ou de lieu
- [ ] `EF-NOT-03` Rappel de non-réponse à J-3 et J-1
- [ ] `EF-NOT-04` Articles non attribués à J-1, à l'organisateur
- [ ] `EF-NOT-05` Rappel de début d'événement à 2 heures
- [ ] `EF-NOT-06` Montant dû, au lendemain de l'événement
- [ ] `EF-NOT-07` Désactivation par catégorie
- [ ] `EF-NOT-08` Mise en sourdine d'un événement
- [ ] `RG-NOT-01` Silence entre 22 h et 8 h, hors rappel de début
- [ ] `RG-NOT-02` Regroupement : une notification d'activité par événement et par quart d'heure
- [ ] `RG-NOT-03` Consentement demandé au moment utile, pas au premier lancement
- [ ] Mettre en place l'ordonnanceur des tâches de fond
- [ ] Écrans : notifications, préférences de notification

## Lot 1.12 — Interface et navigation

- [ ] Écrans de démarrage et de découverte
- [ ] `RG-UI-01` Barre inférieure à cinq entrées, le reste sous « Plus »
- [ ] Écrans profil et paramètres
- [ ] `NF-OFFLINE-01` Consultation du dernier état chargé et file d'attente des écritures
- [ ] `NF-PERF-04` Premier affichage utile en moins de 2,5 s en 4G
- [ ] `NF-A11Y-03` Libellés sémantiques sur toute action

## Lot 1.13 — Sécurité et conformité

- [ ] `RG-SEC-02` Test de cloisonnement sur chaque endpoint, réponse 404
- [ ] `NF-SEC-02` Aucun secret dans le dépôt
- [ ] `NF-SEC-03` Aucun montant, adresse ou jeton en clair dans les journaux
- [ ] `EF-RGPD-01` Export complet des données au format JSON
- [ ] `EF-RGPD-02` Suppression de compte effective sous 30 jours
- [ ] `RG-RGPD-01` Anonymisation des contributions financières à la suppression
- [ ] `EF-RGPD-03` Rectification des données d'identité
- [ ] `EF-RGPD-04` Retrait du consentement par catégorie
- [ ] `RG-RGPD-02` Droits exerçables par un invité sans compte
- [ ] Rédiger le registre des traitements — `§12.1`

## Lot 1.14 — Exploitation

- [ ] `NF-OPS-03` Brancher un outil de suivi d'erreurs
- [ ] `NF-OPS-04` Sauvegarde quotidienne, rétention 30 jours, dépôt hors serveur
- [ ] `NF-OPS-05` **Réaliser une restauration de test avant l'ouverture de la bêta**
- [ ] `NF-OPS-07` Alertes : indisponibilité, 5xx > 1 %, saturation disque, échec de sauvegarde
- [ ] Rédiger la procédure d'exploitation : déploiement, retour arrière, restauration
- [ ] Vérifier `NF-PERF-01` et `NF-PERF-02` sous charge représentative
- [ ] `NF-SCAL-01` Valider la tenue de la cible : 5 000 événements actifs, 50 000 membres
- [ ] `NF-DISPO-01` Mettre en place la mesure de disponibilité, objectif 99,0 % mensuel
- [ ] `NF-OPS-06` Documenter et vérifier les objectifs de reprise : RPO 24 h, RTO 4 h

## Lot 1.15 — Documents légaux

- [ ] Conditions générales d'utilisation
- [ ] Politique de confidentialité, incluant `RG-RGPD-01`
- [ ] Mentions légales
- [ ] `RG-LEG-01` Mention explicite : PartyPlan ne détient ni ne transfère aucun fonds
- [ ] Fiche de confidentialité Google Play
- [ ] Politique de cookies (aucun cookie non essentiel au lancement)

## Lot 1.16 — Site vitrine

- [ ] Page d'accueil : proposition de valeur, captures, lien vers l'application
- [ ] Pages légales publiées
- [ ] Page de support et adresse de contact

## Lot 1.17 — Recette et bêta privée

- [ ] Rédiger la grille de recette manuelle — `§15`
- [ ] Test bout en bout automatisé du parcours complet
- [ ] `NF-QUAL-02` Couverture globale du domaine supérieure à 70 %
- [ ] `NF-COMPAT-01` Recette sur Android 8.0 et supérieur
- [ ] `NF-COMPAT-03` Recette sur les deux dernières versions majeures de Chrome, Safari, Firefox, Edge
- [ ] **Trois groupes réels menant un événement complet jusqu'aux remboursements marqués**
- [ ] Traiter les retours de la bêta
- [ ] Vérifier les critères 13 à 26 du `§18`

## Lot 1.18 — Publication

- [ ] Publier la PWA
- [ ] Créer la fiche Google Play : description, captures, icône, classification
- [ ] Signer et publier la version Android
- [ ] Mettre en place la mesure d'usage des objectifs `OBJ-01` à `OBJ-05`
- [ ] `EF-ADM-14` Exposer ces indicateurs dans le back-office *(P2, peut glisser en V2)*

---

# V1.1 — Collaboration

Objectif : ce qui remplace le reste des messages du groupe.

## Lot 2.1 — Tâches

- [ ] `EF-TSK-01` Créer une tâche : libellé, responsable, échéance
- [ ] `EF-TSK-02` S'attribuer, marquer faite, annuler
- [ ] `EF-TSK-03` Avancement sur le tableau de bord

## Lot 2.2 — Sondages

- [ ] `EF-SDG-01` Sondage à choix unique, 2 à 10 options
- [ ] `EF-SDG-02` Voter et changer son vote
- [ ] `EF-SDG-03` Résultats avec décompte
- [ ] `EF-SDG-04` Clôture d'un sondage

## Lot 2.3 — Discussion

- [ ] `EF-MSG-01` Message texte dans l'événement
- [ ] `EF-MSG-02` Pièce jointe image
- [ ] `EF-MSG-03` Réactions emoji
- [ ] `EF-MSG-04` Réponse et mention
- [ ] `EF-MSG-05` Suppression de son propre message
- [ ] `RG-MSG-01` S'en tenir là : aucune fonction de messagerie généraliste

## Lot 2.4 — Groupes permanents

- [ ] `EF-GRP-01` Créer un groupe et y ajouter des membres
- [ ] `EF-GRP-02` Créer un événement en invitant tout un groupe
- [ ] `EF-GRP-03` Retirer un membre sans effet sur les événements passés
- [ ] `EF-INV-08` Réinviter un groupe en une action

## Lot 2.5 — Compléments

- [ ] `EF-EVT-08` Image de couverture d'événement
- [ ] `EF-EVT-09` Archivage d'un événement passé
- [ ] `EF-EVT-10` Duplication d'un événement
- [ ] `EF-INV-07` Invitation par courriel depuis l'application
- [ ] `EF-PRES-06` Nombre d'accompagnants
- [ ] `EF-PRES-07` Relance des membres sans réponse
- [ ] `EF-CRS-11` Réordonnancement et regroupement des articles
- [ ] `EF-CRS-12` Saisie de plusieurs articles en une fois
- [ ] `EF-DEP-06` Photo de ticket
- [ ] `EF-DEP-07` Rattachement d'une dépense à un article
- [ ] `EF-RMB-06` Notification du créditeur lors d'une déclaration de remboursement
- [ ] `EF-RMB-07` Double validation du remboursement par le créditeur
- [ ] `EF-PLN-05` Participants d'une étape du planning
- [ ] `EF-PLN-06` Rappel sur une étape
- [ ] `EF-NOT-09` Repli courriel des notifications

## Lot 2.6 — Publication V1.1

- [ ] Recette de non-régression sur le parcours MVP
- [ ] Publication PWA et Google Play

---

# V1.2 — iOS

Objectif : présence sur l'App Store.

- [ ] `EF-AUTH-07` Connexion Apple — **prérequis au dépôt si Google est proposé**, `R-05`
- [ ] Configurer le compte développeur Apple, certificats et profils
- [ ] Adapter l'interface aux particularités iOS (zones sûres, retour par geste)
- [ ] Notifications poussées iOS
- [ ] `R-06` Traiter la limitation des notifications sur PWA iOS : repli courriel, incitation à l'ajout à l'écran d'accueil
- [ ] `NF-COMPAT-02` Recette sur iOS 15 et supérieur
- [ ] Fiche App Store et fiche de confidentialité
- [ ] Soumission et publication

---

# V2.0 — Premium

Objectif : premier revenu, sans dégrader la gratuité qui porte la viralité.

## Lot 4.1 — Socle d'abonnement

- [ ] `EF-PRM-01` Abonnement 2,99 €/mois ou 19,99 €/an
- [ ] Intégrer les achats intégrés Google Play et App Store
- [ ] Intégrer le paiement web pour la PWA
- [ ] Gérer le cycle de vie : renouvellement, expiration, remboursement, rétablissement d'achat
- [ ] `EF-PRM-03` Les fonctions Premium bénéficient à tous les membres de l'événement d'un abonné
- [ ] `RG-PRM-01` Appliquer les limites de la formule gratuite : 20 participants, archives 3 mois
- [ ] `RG-PRM-02` L'atteinte d'une limite ne dégrade jamais un événement en cours
- [ ] `RG-PRM-03` Aucune fonction du MVP ne devient payante rétroactivement
- [ ] Écran Premium et parcours d'abonnement
- [ ] Mettre à jour les conditions générales pour l'abonnement

## Lot 4.2 — Fonctions Premium — `EF-PRM-02`

- [ ] `EF-EVT-11` Créer un événement depuis un modèle
- [ ] `EF-CRS-13` Générer une liste de courses depuis un modèle
- [ ] Écrire les modèles : barbecue, anniversaire, week-end, raclette, réveillon, festival
- [ ] `EF-DEP-08` Plusieurs groupes de partage dans un même événement
- [ ] `EF-DEP-09` Export PDF et tableur des dépenses
- [ ] `EF-SDG-05` Sondages avancés : choix multiple, anonyme, date limite
- [ ] Thèmes et personnalisation de l'événement
- [ ] Rappels avancés configurables
- [ ] Archives illimitées
- [ ] Au-delà de 20 participants

---

# V2.1 — IA, statistiques, intégrations

- [ ] `EF-CRS-14` Proposition de quantités selon le nombre de présents
- [ ] Génération d'une liste de courses en langage naturel (« raclette pour 8 »)
- [ ] Statistiques d'événement et de groupe
- [ ] `EF-RMB-08` Liens de paiement : Lydia/Sumeria, Revolut, PayPal, IBAN — sans jamais détenir les fonds (`HP-01`)
- [ ] `EF-PLN-07` Export iCalendar du planning
- [ ] Synchronisation Google Calendar et Apple Calendar
- [ ] `EF-EVT-12` Événements récurrents
- [ ] Widgets Android et iOS
- [ ] Gamification légère : MVP de la soirée, banquier officiel, roi des courses

---

# Non planifié

Idées conservées, sans version affectée. À ne pas commencer avant une demande explicite.

- [ ] Multi-devise — `HP-05`
- [ ] Géolocalisation et carte du lieu — `RG-EVT-03`
- [ ] Partage de photos de l'événement après la soirée
- [ ] Traduction en anglais — `NF-I18N-01` rend la chose possible sans refonte
- [ ] Mode organisateur professionnel (associations, BDE)

---

# Hors périmètre définitif

À rappeler à chaque tentation d'élargissement — `§2.4`.

| Réf | Exclusion | Motif |
|---|---|---|
| `HP-01` | Encaissement ou transfert de fonds | Agrément d'établissement de paiement |
| `HP-02` | Messagerie généraliste hors événement | Non concurrentiel |
| `HP-03` | Découverte d'événements publics, réseau social | Privé par défaut |
| `HP-04` | Billetterie, événements commerciaux | Autre marché |
| `HP-05` | Multi-devise | Coût sur tous les calculs, cas marginal |

---

# Décisions en attente

À trancher avant le lot concerné, sous peine de blocage.

| À trancher | Bloque | Échéance |
|---|---|---|
| Nom définitif et disponibilité INPI / `partyplan.fr` | Lot 0.1, toute l'identité visuelle | **bloquant maintenant** |
| Hébergeur retenu et son emplacement dans l'UE | Lot 0.7 | **bloquant maintenant** |
| Un « +1 » doit-il porter une part de dépense dès le MVP ? | Lot 1.7 | avant V1.0 |
| La double validation des remboursements passe-t-elle en V1.0 ? | Lot 1.8 ou 2.5 | avant V1.0 |
| Confirmation des hypothèses restantes du `§19` | plusieurs lots | avant V0.5 |
| ~~Mot de passe ou lien magique~~ | — | **tranché le 19/08/2026 : mot de passe, HY-01 révisé** |
