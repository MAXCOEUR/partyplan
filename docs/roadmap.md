# Feuille de route PartyPlan — tout ce qui reste à faire

> Document unique de suivi. Chaque ligne est une tâche à cocher.
> Les références `EF-`, `RG-`, `NF-` renvoient au [cahier des charges](cahier-des-charges.md),
> où la règle précise est écrite. Ne rien ajouter ici sans référence : si une tâche
> n'existe pas dans le cahier des charges, c'est le cahier des charges qu'il faut
> compléter d'abord.

Mise à jour : **24/08/2026** — remise au niveau réel du code, qui avait plusieurs lots
d'avance sur ce document. Courses, dépenses, remboursements, invitations avec compte,
discussion et sondages sont livrés. L'`ADR 0007` retire la double authentification. Le
planning est abandonné.

> **Comment ce retard s'est créé, pour ne pas le refaire** : les lots 1.3, 1.5, 1.7 et
> 1.8 étaient intégralement décochés alors que leur code, leurs écrans et leurs tests
> existaient. Un document de suivi qui décrit un état faux est pire qu'absent — on y lit
> du travail à faire qui est fait, et on croit fait ce qui ne l'est pas. Cocher au
> moment du commit, pas à la fin du lot.

## Comment lire ce document

| Version | Contenu | Cible de publication |
|---|---|---|
| **V0** | Socle technique et environnement local. Rien de visible. | interne |
| **V0.5** | **Comptes et administration.** Développé en premier : inscription, profil, photo, sessions, administrateur amorcé, back-office, journal d'audit. | interne |
| **V1.0** | MVP événementiel : présence, courses, dépenses, remboursements, discussion, sondages. *(Planning abandonné ; discussion et sondages remontés de V1.1.)* | PWA + Google Play |
| **V1.1** | Collaboration : tâches, groupes permanents, compléments. *(Sondages et discussion livrés en V1.0.)* | PWA + Google Play |
| **V1.2** | Portage iOS. | App Store |
| **V2.0** | Offre Premium et modèles d'événements. | toutes plateformes |
| **V2.1** | IA, statistiques, intégrations système. | toutes plateformes |

Règle de progression : une version ne s'ouvre que lorsque la précédente est publiée.
Toute tâche non cochée d'une version publiée devient une anomalie, pas un report.

---

## Avancement

| Version | Tâches faites | Reste |
|---|---|---|
| V0 — socle technique | lots 0.2 à 0.6, dépôt GitHub et protection de branche | lot 0.1 (INPI, nom, logo, hébergeur, DNS), lot 0.7 (serveur) |
| V0.5 — comptes et administration | lots 0.8 à 0.14 | connexion Google (identifiants Google Cloud requis) |
| V1.0 — MVP événementiel | lots 1.2 à 1.5, 1.7, 1.8, le socle hors ligne du lot 1.12, plus la discussion et les sondages remontés de V1.1 | fil d'activité (1.10), temps réel (1.6), notifications (1.11), conformité (1.13), exploitation (1.14), légal (1.15), vitrine (1.16), recette et publication (1.17, 1.18) |

Décisions d'architecture prises : `ADR 0001` monorepo, `ADR 0002` monolithe modulaire,
`ADR 0003` domaines et certificats, `ADR 0004` chaîne de livraison, `ADR 0005` identité
et administration, `ADR 0006` compte obligatoire pour rejoindre, `ADR 0007` retrait de
la double authentification.

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
- [ ] Choisir l'hébergeur, situé dans l'Union européenne — `RG-RGPD-03` ; voir `docs/comptes-externes.md` §6
- [ ] Créer les enregistrements DNS : `partyplan`, `api.partyplan`, `cdn.partyplan`
- [x] Dépôt GitHub privé créé et poussé — `MAXCOEUR/partyplan`
- [x] Protection de la branche `main` : contrôles obligatoires (frontières, format C#, format Dart, vulnérabilités), poussée forcée et suppression interdites
  - → **revue obligatoire volontairement non activée** : à un seul développeur, GitHub
    interdit d'approuver sa propre pull request, la règle bloquerait donc toute fusion.
    À activer le jour où une seconde personne rejoint le projet.
  - → `enforce_admins` laissé à faux, afin de conserver une issue en cas d'urgence

## Lot 0.2 — Outillage du dépôt

- [x] `.editorconfig` : conventions C# et Dart, nommage, style
- [x] Modèle de pull request rappelant les règles non négociables — `.github/pull_request_template.md`
- [x] `NF-SEC-05` Analyse des vulnérabilités en CI, transitives incluses, blocage sur gravité élevée ou critique
- [x] `ADR 0002` Contrôle automatisé des frontières de modules — `tools/verifier-frontieres-modules.sh`, exécuté en CI
- [x] Contrôle CI de format : `dotnet format --verify-no-changes` et `dart format --set-exit-if-changed`
- [x] `NF-OPS-08` Interdiction de construire une image sur le serveur — `ADR 0004` et `docs/exploitation.md` §6
- [x] `NF-OPS-09` Contrôle que tout secret figure dans les `.env.example` — par revue, via le modèle de pull request
- [x] `NF-OPS-09` automatisé — `tools/verifier-variables-env.sh`, exécuté par `make lint` et en CI
  - → a immédiatement trouvé un vrai défaut de production : `Media:PublicBaseUrl` n'était jamais injecté, les adresses des photos de profil auraient pointé vers `localhost`

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
- [x] Guide de développement local — `docs/developpement.md` : Rider, Android Studio, émulateur, problèmes courants
- [x] Cibles `make android`, `make emulateur`, `make lan`, `make devices` ; l'API écoute sur `0.0.0.0:5080` afin d'être joignable depuis l'émulateur
- [x] Diagnostic et repli sur les limites inotify du noyau — `make inotify`, saturées par Rider et Android Studio sur le poste de développement
- [ ] Relever `fs.inotify.max_user_instances` sur le poste (droits d'administration requis) — voir `docs/developpement.md` §6 bis
- [x] `NF-DEV-04` Émetteur de notifications journalisant en console faute de clé, sans faire échouer l'action métier
- [x] `NF-DEV-05` L'inscription et la connexion fonctionnent sans aucune clé Google configurée — vérifié par la recette et par 64 tests d'intégration qui tournent sans variable `GOOGLE_*`
- [x] `NF-DEV-06` Administrateur de développement amorcé, identifiants documentés, garde en place
- [x] `NF-DEV-10` Tests vérifiés sans accès Internet : 177 unitaires dans un espace de noms réseau isolé, 64 d'intégration avec la sortie Internet bloquée
  - → **limite honnête** : les tests d'intégration exigent la mise en réseau Docker locale — le processus de test dialogue en TCP avec le conteneur PostgreSQL. Ils n'ont besoin d'aucun accès Internet, à condition que l'image `postgres:16-alpine` soit déjà en cache

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
- [x] `§8.1` Idempotence des créations, appliquée à la création d'événement
  - → intergiciel et non filtre d'endpoint : un filtre s'exécute après le liage des arguments, donc après consommation du corps, et l'empreinte était calculée sur une chaîne vide — deux requêtes différentes portaient la même empreinte
  - → la réponse rejouée est sérialisée aux conventions de l'hôte : les options par défaut produisent du PascalCase là où l'hôte émet du camelCase, et le client casserait au rejeu
  - → seules les réussites sont mémorisées : rejouer un échec empêcherait de corriger une requête et de la renvoyer avec la même clé

## Lot 0.4 — Base de données

- [x] `DbContext` unique, EF Core 10 et Npgsql, implémentant les onze contrats de module
- [x] Entités des **26 tables** du `§7.2` — 27 jusqu'au retrait de `totp_recovery_codes` (`ADR 0007`)
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
- [x] Stockage sécurisé de la session de compte
- [x] Client HTTP unique avec injection du jeton, en-tête d'idempotence et traduction des erreurs RFC 9457
- [x] États génériques de chargement, d'erreur et de vide
- [x] Manifeste PWA, `index.html` en `noindex`, service worker Flutter
- [x] Script de génération du client Dart depuis l'OpenAPI — `tools/generate-api-client.sh`
- [x] Image Docker web construite (80 Mo), route profonde et en-têtes de sécurité vérifiés en service
- [x] Rafraîchissement automatique de session à l'expiration du jeton d'accès — sans lui, l'utilisateur serait déconnecté tous les quarts d'heure
- [x] **Décision** : le client Dart reste écrit à la main. Le générateur produit un paquet séparé et une chaîne de compilation supplémentaire, disproportionnés pour une quarantaine d'endpoints. `tools/generate-api-client.sh` reste disponible le jour où la surface le justifiera.

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
- [x] `NF-I18N-01` Chaînes regroupées, aucune en dur dans un écran
- [x] Migrer `PpStrings` vers des fichiers ARB traduits
  - → `lib/l10n/arb/app_fr.arb` et génération par `make l10n` ; les fichiers générés ne sont pas
    versionnés, ce qui rend impossible une divergence silencieuse avec les ARB
  - → délégués Material uniquement : la liste générée embarque les libellés Cupertino et
    faisait réclamer par la compilation une police d'icônes absente
  - → le nom du produit reste hors des ARB (`PpMarque`) : un nom de produit ne se traduit pas
  - → les tests montent désormais `PartyPlanApp` et non un `MaterialApp` nu, faute de quoi ils
    ne voyaient pas la même application que la production

## Lot 0.7 — Déploiement initial

- [x] Documenter la procédure de déploiement, de retour arrière, de sauvegarde et de restauration — `docs/exploitation.md`
- [x] Pile prête à coller pour un NAS UGREEN derrière Nginx Proxy Manager — `infra/compose/compose.nas.example.yml`
  - → Caddy retiré : le NAS a déjà un reverse proxy, en conserver deux ferait deux
    autorités concurrentes sur le TLS et les en-têtes
  - → un service `cdn` reprend le service des photos : en production l'API ne sert
    pas les fichiers statiques, c'est Caddy qui le faisait
  - → HSTS est le seul en-tête que les images ne portent pas ; il revient au proxy
    qui termine le TLS, donc à NPM
  - → l'adresse de l'API est inscrite dans l'image web à la compilation : changer de
    domaine impose de republier l'image, pas de modifier le compose
- [ ] Provisionner le serveur — premier déploiement sur NAS UGREEN
- [ ] Installer Docker et Compose
- [ ] Déployer la pile `compose.nas.example.yml`
- [ ] Rendre publics les trois paquets GHCR, faute de quoi le NAS ne peut pas les tirer
- [ ] Vérifier l'obtention des certificats sur les quatre domaines
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
| Migration appliquée sur PostgreSQL 16 | 27 tables, 4 contraintes de contrôle *(26 depuis l'`ADR 0007`)* |
| Journal d'audit | `UPDATE`, `DELETE` et `TRUNCATE` refusés, ligne intacte |
| Cloisonnement | membre 200, non-membre 404, `PlatformAdmin` non membre 404, anonyme 401 ; le comportement invité est historique et remplacé par l'ADR 0006 |
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
événementielle n'existe.

**État au 19/08/2026 : lots 0.8 à 0.14 livrés côté API et côté application, vérifiés de
bout en bout.** Reste la connexion Google, qui suppose des identifiants Google Cloud. La
double authentification, livrée puis retirée le 24/08/2026 (`ADR 0007`), ne figure plus
au périmètre.

## Lot 0.8 — Authentification par mot de passe

- [x] `EF-AUTH-01` Inscription par adresse e-mail et mot de passe
- [x] `RG-AUTH-01` 12 caractères minimum, refus des mots de passe compromis, aucune expiration périodique
  - → liste embarquée de 45 567 condensés tronqués, sans aucun mot de passe en clair, enrichie des variantes françaises et des suites de clavier
- [x] `RG-AUTH-02` Hachage Argon2id, jamais de mot de passe journalisé ni consultable
- [x] `EF-AUTH-02` Connexion par adresse e-mail et mot de passe
- [x] `EF-AUTH-03` Vérification de l'adresse e-mail par lien
- [x] `EF-AUTH-04` Réinitialisation du mot de passe par lien
- [x] `RG-AUTH-03` Liens valables 15 minutes, usage unique, condensé seul stocké
- [x] `RG-AUTH-04` Réponse identique que l'adresse existe ou non
- [x] `EF-AUTH-05` Changement de mot de passe avec l'ancien
- [x] `RG-AUTH-05` Limite par adresse tenue par le service, limite par IP par le limiteur HTTP, ralentissement croissant après dix échecs, aucun verrouillage définitif
- [x] `RG-AUTH-06` Révocation des autres sessions à la réinitialisation et au changement d'adresse
- [x] `EF-AUTH-09` Session de 90 jours, prolongée à l'usage, avec rotation du jeton de rafraîchissement
- [x] `EF-AUTH-10` Liste des sessions actives, révocation d'une session ou de toutes
- [x] Écrans : connexion, inscription, mot de passe oublié, sécurité et sessions

## Lot 0.9 — Connexions tierces *(la double authentification a été retirée)*

**Retrait acté le 24/08/2026 — `ADR 0007`.** La double authentification livrée ici —
RFC 6238 implémentée dans le dépôt, huit codes de secours, secret chiffré en AES-GCM,
connexion en deux temps — est **supprimée du produit** : plus d'endpoint, plus de
colonne, plus de défi à la connexion, plus d'obligation de rôle. Le motif tient en une
phrase : `RG-ADM-04` rendait le back-office inatteignable à son seul administrateur, le
compte amorcé n'ayant pas de second facteur et l'activer supposant d'y accéder. L'ADR
nomme le prix payé — le mot de passe devient l'unique protection d'un compte
d'administration — et les conditions d'un retour.

- [x] Retrait complet et vérifié — `SansDoubleAuthentificationTests` couvre les quatre
      dimensions : route absente (404), contrat sans champ de défi, schéma sans colonne
      ni table, autorisation accordée sur le seul rôle
  - → le retrait du 21/08/2026 n'était que partiel : écrans supprimés et défi retiré,
    mais endpoints, colonnes et secrets conservés. Un compte ayant activé la 2FA se
    connectait donc avec son seul mot de passe pendant que l'API annonçait encore la
    protection. C'est ce demi-état qui a motivé de trancher entièrement.
  - → `ISecretProtector` et `Security:EncryptionKey` partent avec leur unique usage :
    faire générer et faire tourner par l'exploitant une clé qui ne protège rien est un
    piège, pas une précaution
- [x] `RG-ADM-10` Changement de mot de passe imposé au compte amorcé, appliqué par intergiciel
- [x] `NF-SEC-11` Limites de débit paramétrables — les tests partagent une adresse IP et épuisaient une limite pensée pour un utilisateur unique
- [x] `EF-AUTH-06` Connexion Google — parcours complet, Android et Web
  - → `GET /v1/auth/providers/available`, anonyme : l'écran de connexion doit savoir avant
    toute session s'il peut proposer le bouton. `GET /v1/auth/providers` exige une session
    et répond sur le compte courant, il ne pouvait pas servir ici
  - → le bouton exige **deux** conditions : l'instance possède la clé, et l'application
    embarque un identifiant client (`--dart-define=GOOGLE_CLIENT_ID`). L'une sans l'autre
    donnerait un bouton condamné
  - → rattachement depuis l'écran des moyens de connexion, et oubli du compte Google à la
    déconnexion — sans quoi un appareil partagé reconnecterait le titulaire précédent
  - → Android et Web. La **forme** du bouton dépend de la plateforme, pas son
    existence : Android accepte le parcours programmatique et utilise le bouton de
    l'application ; le Web le refuse et impose celui du SDK Google, dont l'apparence
    n'est pas négociable. Le jeton arrive alors par `authenticationEvents`
  - → `serverClientId` est interdit sur le Web par une assertion du greffon, et
    `clientId` ignoré sur Android : les deux paramètres sont posés séparément
  - → reste à faire par l'exploitant : déclarer les origines JavaScript autorisées du
    client Web dans Google Cloud (`http://localhost:5173` et
    `https://web.partyplan.maxencecoeur.fr`), voir `docs/comptes-externes.md` §1
  - → **non vérifié de bout en bout sur navigateur** : le bouton rendu exige le vrai
    SDK Google et un domaine autorisé, qu'aucun test automatisé ne peut fournir
- [x] `EF-AUTH-08` Détachement d'une connexion tierce, et écran des moyens de connexion
  - → `GET /v1/auth/providers` distingue « l'instance n'a pas les clés » de « le compte est
    rattaché » : une clé retirée ne doit pas rendre un compte indétachable
  - → le sujet transmis par le fournisseur n'est jamais exposé
  - → le rattachement depuis l'application attend un client Google (`EF-AUTH-06`) ; l'écran
    le dit plutôt que d'afficher un bouton condamné à échouer
- [x] `RG-AUTH-08` Un compte sans mot de passe en définit un par le parcours de réinitialisation — le lui refuser l'enfermerait dans une dépendance au fournisseur tiers
- [x] `NF-DEV-05` Inscription et connexion vérifiées sans aucune clé Google — voir lot 0.2b
- [x] Écran de rattachement des connexions tierces

## Lot 0.10 — Compte et profil

- [x] `EF-USR-01` Consultation du profil
- [x] `EF-USR-02` Modification du nom affiché
- [x] `RG-USR-04` Nom conservé sur les événements en cours, historique dans le fil d'activité
- [x] `EF-USR-03` Changement d'adresse e-mail avec vérification préalable
- [x] `RG-USR-01` JPEG, PNG, WebP, HEIC, 5 Mo maximum, trois tailles, conversion WebP, suppression des EXIF
- [x] `NF-SEC-09` Type validé par décodage effectif, non par le type déclaré ; taille plafonnée avant lecture
- [x] `EF-USR-06` Suppression de la photo et retour à l'avatar par défaut
- [x] `RG-USR-02` Avatar par défaut généré localement à partir des initiales, sans service externe
- [x] `RG-USR-03` Photos servies sous une adresse contenant une empreinte du contenu
- [x] `EF-USR-07` Choix de la langue et du fuseau horaire, fuseau inconnu refusé
- [x] `EF-USR-09` Export de toutes ses données au format JSON
- [x] `EF-USR-10` Suppression de son compte depuis l'application
- [x] `RG-USR-05` Anonymisation expliquée avant confirmation, confirmation par saisie de l'adresse
- [x] `RG-USR-06` Un compte supprimé libère son adresse e-mail
- [x] Écrans : profil, édition, sécurité, mes données
- [x] `EF-USR-04` Téléversement de la photo depuis l'interface
  - → le type MIME est déduit du nom et déclaré explicitement : Dio annonce sinon
    `application/octet-stream`, que le serveur refuse ; couvert par six tests
  - → taille contrôlée avant envoi, format non reconnu refusé localement
- [x] `EF-USR-05` Recadrage avant envoi, carré, facultatif
  - → indisponible sur le web, où le fichier n'a pas de chemin local ; sans conséquence, le
    serveur recadre de toute façon au centre
  - → le recadreur réencode en JPEG : le nom est ajusté, sinon les octets contrediraient
    le type déclaré
- [ ] `EF-USR-08` Écran de préférences de notification — sans objet avant le lot 1.11

## Lot 0.11 — Amorçage de l'administrateur

- [x] `EF-ADM-01` Création du compte administrateur au démarrage depuis l'environnement
- [x] `RG-ADM-09` Opération idempotente, mot de passe d'amorçage jamais réappliqué
- [x] `RG-ADM-11` Refus de démarrer si l'amorçage est incomplet ou le mot de passe faible
- [x] `RG-ADM-12` Avertissement au démarrage invitant à retirer `ADMIN_PASSWORD`
- [x] Test : base vierge puis second démarrage, aucun doublon
- [x] `RG-ADM-10` Changement de mot de passe imposé et appliqué : seuls le profil, le changement de mot de passe et la déconnexion restent permis

## Lot 0.12 — Back-office d'administration

- [x] `EF-ADM-02` Liste des comptes : recherche par nom ou adresse, tri, pagination
- [x] `EF-ADM-03` Fiche technique d'un compte
- [x] `EF-ADM-04` Déclenchement d'une réinitialisation de mot de passe
- [x] `RG-ADM-02` Un administrateur ne définit, ne consulte, ni ne transmet jamais un mot de passe
- [x] `EF-ADM-05` Révocation de toutes les sessions d'un utilisateur
- [x] `EF-ADM-06` Suspension avec motif obligatoire, et réactivation
- [x] `RG-ADM-07` Un compte suspendu ne peut plus se connecter, sessions révoquées, données intactes
- [x] `EF-ADM-07` Suppression d'un compte, avec la même anonymisation que l'auto-suppression
- [x] `EF-ADM-08` Promotion et révocation des rôles `Support` et `PlatformAdmin`
- [x] `RG-ADM-03` Interdiction de se supprimer, de se révoquer, ou de supprimer le dernier administrateur
- [x] `RG-ADM-05` Le rôle `Support` limité à la consultation et au dépannage
- [x] `EF-ADM-09` Consultation du journal d'audit
- [x] `EF-ADM-10` Indicateurs d'instance
- [x] `RG-ADM-08` Écrans d'administration sous `/admin/*`, accessibles aux seuls rôles plateforme
- [x] Écrans : liste des comptes avec actions, journal d'audit
- [x] `EF-ADM-11` Forcer la vérification d'une adresse — bouton présent sur la fiche du compte, visible seulement si l'adresse ne l'est pas
- [x] `EF-ADM-12` Export des données d'un utilisateur ne pouvant plus se connecter — même contenu que l'export en libre-service, journalisé car c'est un accès à des données personnelles
- [x] `EF-ADM-13` Suppression d'une photo de profil signalée, idempotente
- [x] `EF-ADM-10` Indicateurs complétés par les décomptes d'événements, via le contrat `IEventStatistics` — des nombres, jamais de contenu (`RG-ADM-01`), vérifié par test

## Lot 0.13 — Cloisonnement et audit

- [x] `RG-ADM-01` Aucun rôle plateforme ne donne accès au contenu d'un événement
- [x] Test d'intégration : un `PlatformAdmin` non membre reçoit 404 sur chaque endpoint d'événement
- [x] Test d'intégration : un `User` puis un `Support` sur les endpoints `/v1/admin/*`
- [x] `RG-ADM-06` Journal d'audit immuable : auteur, cible, action, motif, horodatage, adresse IP
- [x] `NF-SEC-08` Déclencheur couvrant `UPDATE`, `DELETE` et `TRUNCATE` sur les tables en ajout seul
- [x] `RG-RGPD-04` Adresse de l'auteur recopiée, aucune clé étrangère vers les comptes
- [x] `NF-SEC-06` Argon2id et refus des mots de passe compromis vérifiés par test
- [ ] `RG-RGPD-04` Décrire le périmètre d'accès du support dans la politique de confidentialité — lot 1.15

## Lot 0.14 — Recette V0.5

- [x] Recette exécutable de bout en bout — `tools/recette/parcours-comptes.py`,
      **65 vérifications** après le retrait de la section double authentification
      (`ADR 0007`), rejouée le 24/08/2026
- [x] Tests d'intégration automatisés des mêmes règles, exécutables en CI sans serveur de courriel
- [x] Vérifier les critères 1, 2, 4, 5, 7 à 12 du `§18`
- [x] Critère 3 du `§18` : refus de démarrage sur amorçage incomplet, couvert par huit cas dont la frontière exacte de douze caractères
- [x] Critère 6 du `§18` : changement de mot de passe imposé au compte amorcé — le second facteur en est retiré depuis l'`ADR 0007`
- [x] Recette étendue, premier démarrage complet compris
  - → les deux recettes sont désormais **rejouables sur une base déjà amorcée** : la
    connexion administrateur essaie le mot de passe d'amorçage puis celui qu'elle a
    elle-même changé, et `RG-ADM-10` est explicitement *ignorée* — jamais déclarée
    réussie — lorsque l'obligation a déjà été consommée. Une recette qui ne peut tourner
    qu'une fois par base cesse d'être lancée

---

# V1.0 — MVP événementiel

Objectif : le parcours complet « créer une soirée → inviter → répondre → courses →
prix → remboursements » fonctionne en production.
Sortie : les critères 13 à 26 du `§18` sont vérifiés.

## Historique — Lot 1.1, rattachement des invités sans compte (remplacé par l'ADR 0006)

- [x] **Historique** — `RG-AUTH-07` L'empreinte du jeton d'invité était conservée à l'adhésion : c'est elle, et jamais le prénom, qui portait le rattachement
- [x] **Historique** — `EF-AUTH-11` Conversion d'une participation d'invité en compte permanent
  - → endpoint authentifié `POST /v1/auth/guest-claim`, et non un champ ajouté à
    l'inscription : l'API compte quatre points d'ouverture de session — inscription,
    connexion, second facteur, connexion tierce — et un champ n'en couvrirait que deux,
    faisant perdre silencieusement sa participation à tout compte à second facteur
  - → le contrat reçoit le jeton brut, pas son empreinte : l'algorithme reste interne à
    `Events`, sans quoi n'importe quel module pourrait forger une empreinte
- [x] Test : aucun doublon de membre après conversion
  - → deux homonymes ne fusionnent pas : la liaison se fait sur l'empreinte du jeton
  - → **reste à faire en B2** : réaffecter les contributions financières lorsqu'un
    compte déjà membre absorbe sa propre ligne d'invité, faute de quoi le critère
    « la dépense reste rattachée à lui » serait faux

## Lot 1.2 — Événements

- [x] `EF-EVT-01` Créer un événement : nom, date, heure, lieu, description
- [x] `EF-EVT-02` Date de fin facultative, sinon fin implicite à +12 heures
- [x] `EF-EVT-03` Modifier l'événement ; un changement de date ou de lieu est inscrit au fil d'activité
- [x] `EF-EVT-05` Liste « à venir » et « passés », avec rôle et statut de l'appelant
- [x] `EF-EVT-06` Quitter un événement
- [x] `RG-ROLE-01` Rôles `Owner` / `Admin` / `Member` ; un administrateur n'exclut pas le propriétaire et ne supprime pas l'événement
- [x] `RG-ROLE-02` Le propriétaire doit transférer la propriété avant de quitter
- [x] `RG-ROLE-03` L'exclusion horodate la ligne sans la supprimer : les données financières subsistent
- [x] `EF-EVT-07` Supprimer un événement, avec confirmation renforcée
- [x] `RG-EVT-01` En-tête `noindex` sur toute réponse d'API et toute page
- [x] Le créateur devient propriétaire et est déclaré présent
- [x] `EF-EVT-04` Tableau de bord de l'événement
  - → composé de sections autonomes : ajouter une section consiste à créer un fichier
    dans `sections/` et à l'insérer dans une liste ; B2 et B4 ne toucheront pas la page
- [ ] `RG-UI-02` Le tableau de bord affiche l'information actionnable du moment
  - → structure livrée, emplacements réservés et commentés dans la page
  - → **débloqué depuis le 21/08/2026** : `Shopping` et `Settlements` fournissent
    désormais les articles non attribués et le montant dû. Il reste à ajouter les deux
    sections dans `sections/`, avec `EF-RMB-05` qui attend la même chose
- [ ] `RG-EVT-02` Brancher la vérification des règlements en attente — **le contrat
      existe désormais** (`ISettlementStatus`, exposé par Settlements au lot 1.8) mais
      `EventService.SupprimerAsync` ne le consomme pas : la suppression exige toujours
      le drapeau de forçage, que des dettes soient en suspens ou non. Débloqué, à faire.
- [x] Transfert de propriété à un autre membre — sans lui, `RG-ROLE-02` serait un cul-de-sac : l'organisateur resterait prisonnier de son propre événement
  - → l'ancien propriétaire devient administrateur, non membre ordinaire ; la cible est un compte membre, conformément à l'ADR 0006
- [x] Écrans : accueil, création d'événement, tableau de bord, paramètres
  - → assistant de création en trois étapes, navigation libre, « Créer » actif dès
    l'étape 2 : nom et date suffisent à l'API, imposer l'étape 3 ferait de la
    description un champ obligatoire de fait
  - → clé d'idempotence fixée à l'ouverture de l'assistant, pas à l'appui sur « Créer »
  - → dans les paramètres, le transfert précède « quitter » : découvrir l'interdiction
    de `RG-ROLE-02` après avoir appuyé serait un cul-de-sac

## Lot 1.3 — Invitations avec compte et liens profonds

**Livré. `ADR 0006`.** Ce lot était intégralement décoché alors que le code était en
place : la feuille de route avait pris du retard sur les commits.

- [x] `EF-INV-01` Lien d'invitation `/join/{token}` et QR code avec la même URL canonique
  - → QR code dessiné par `qr_flutter` dans `invitation_page.dart`, sur l'URL canonique
- [x] `EF-INV-03` Code court `PLAN-XXXXXX`, avec aperçus publics restreints par jeton et code
- [x] `RG-INV-01` Jeton de 192 bits, encodé en base64url et non déductible de l'identifiant — `InviteToken`
- [x] `RG-INV-02` Alphabet de 32 caractères sans `I`, `O`, `0` ni `1` ; six positions — `ShortCode`
  - → l'unicité ne porte que sur les événements vivants, ce qui laisse le stock se recycler
- [x] `RG-INV-03` Limitation de la résolution de code court — dix tentatives par minute
- [x] `RG-INV-04` Aperçu public : nom, dates, lieu, description et nombre de participants ; jamais membres, dépenses ou jeton long
- [x] `EF-INV-04` POST authentifiés par jeton ou code court, sans nom ni statut dans le corps ; le serveur utilise le profil et crée `Unknown`
- [x] `RG-INV-05` Adhésion idempotente : un rejeu du même compte ne crée pas de doublon ni ne modifie la présence
- [x] Conserver `retour` pendant connexion et inscription avec une allowlist stricte :
  uniquement `/join/{token}` ou `/rejoindre/{code}` après décodage ; rejeter vers `/`
  toute URL absolue, schéma, autorité ou préfixe `//`, fragment, paramètres, segment
  supplémentaire ou autre route
  - → `RetourAuth` et ses tests dédiés ; les délimiteurs encodés sont refusés
- [x] Écrans : aperçu, connexion/création avec retour, adhésion automatique et états fermeture, lien invalide et panne réseau
- [x] Supprimer la création de nouveaux jetons invités et `/v1/auth/guest-claim` ; conserver les lignes sans `user_id` uniquement comme historiques financières
- [x] Configurer Android App Links pour ouvrir directement les invitations ; sans application, ouvrir le Web
  - → vérifié par `tools/verifier-app-links-android.sh` et `app/web/.well-known/assetlinks.json`
- [ ] iOS Universal Links — reporté en V1.2 avec le portage iOS : rien à configurer avant
      d'avoir un compte développeur Apple et un identifiant d'application
- [x] Recette du parcours d'invitation avec compte — `tools/recette/parcours-evenement.py`
  - → elle **testait encore le parcours invité supprimé** par l'`ADR 0006` et ne pouvait
    donc plus passer : réécrite le 24/08/2026 pour l'adhésion avec compte
  - → **84 / 84 vérifications passées** contre une API réelle le 24/08/2026

## Lot 1.4 — Présences

- [x] `EF-PRES-01` Cinq statuts : présent, peut-être, absent, arrive plus tard, part plus tôt
- [x] `EF-PRES-02` Heure d'arrivée et de départ prévues
- [x] `EF-PRES-03` Modification du statut à tout moment ; chacun ne modifie que le sien
- [x] `EF-PRES-04` Liste des membres avec statut, horaires et rôle
- [x] `EF-PRES-05` Synthèse « n présents sur m invités », avec les « peut-être » à part
- [x] `EF-PRES-06` Accompagnants, plafonnés à dix — au-delà il s'agit d'un autre événement
- [x] `RG-PRES-01` Statut initial `Unknown`, jamais présumé présent
- [x] `RG-PRES-02` `Late` et `EarlyLeave` comptent comme présents, y compris dans le total des têtes
- [x] `RG-PRES-03` `Maybe` compté séparément
- [x] `RG-PRES-04` Présents et têtes sont deux décomptes distincts : les confondre fausse toutes les quantités de courses
- [ ] `EF-PRES-07` Relance des membres sans réponse — dépend des notifications (lot 1.11)
- [x] Écran : invités

## Lot 1.5 — Liste de courses

**Livré.** Sept endpoints, écran de liste, feuilles d'article et d'achat.

- [x] `EF-CRS-01` Ajouter un article : libellé, quantité, unité, catégorie
- [x] `EF-CRS-02` Quatre catégories : boissons, nourriture, matériel, autres
- [x] `EF-CRS-03` S'attribuer un article
- [x] `RG-CRS-01` Attribution unique, contrôlée en transaction côté serveur
- [x] `EF-CRS-04` Retirer son attribution
- [x] `EF-CRS-05` Marquer acheté avec quantité réellement obtenue
- [x] `RG-CRS-02` Affichage du reliquat en cas d'achat partiel
- [x] `EF-CRS-06` Prix estimé et prix réellement payé
- [x] `EF-CRS-07` Création automatique d'une dépense à la saisie du prix payé
  - → par le contrat `IExpenseFromPurchase` : Shopping n'écrit pas dans les tables d'Expenses
- [x] `RG-CRS-03` Le prix estimé n'entre jamais dans les calculs
- [x] `EF-CRS-08` Modifier et supprimer un article, refus si une dépense y est rattachée
- [x] `EF-CRS-09` Avancement « n / m pris » et « n / m achetés »
- [x] `EF-CRS-10` Commentaire sur un article
- [x] Test de concurrence : deux attributions simultanées, une seule aboutit — `ChaineFinanciereTests`
- [x] Écran : courses

## Lot 1.6 — Temps réel

**En cours depuis le 25/08/2026** — voir
`docs/superpowers/plans/2026-08-25-temps-reel-signalr.md`. Le `§9` du cahier des charges a
été corrigé d'abord : `schedule.changed` était mort avec le planning, et la discussion
comme les sondages n'étaient pas couverts alors qu'ils sont livrés. 21 messages au lieu
de 18.

- [ ] Exposer le hub SignalR sur `/hubs/event` — `RG-RT-01`
- [ ] Contrôler l'appartenance à l'événement à l'établissement de la connexion
- [ ] Diffuser les 18 messages du `§9`
- [ ] `RG-RT-02` Chaque message porte l'état résultant, pas seulement un identifiant
- [ ] `RG-RT-03` Rechargement complet de l'écran actif à la reconnexion
- [ ] Client Flutter : abonnement, reconnexion, application des messages à l'état local
- [ ] Recette : propagation en moins d'une seconde — `NF-PERF-05`
- [ ] `RG-RT-04` Rester en instance unique : tout ajout d'une seconde instance impose Redis et un ADR préalable

## Lot 1.7 — Dépenses

**Livré.** Cinq endpoints, liste avec totaux, création aux trois assiettes, détail.

- [x] `EF-DEP-01` Créer une dépense : libellé, montant, payeur, date
- [x] `RG-DEP-01` Montant strictement positif, plafonné à 99 999,99 €
- [x] `EF-DEP-02` Trois modes d'assiette : tous les présents, sélection, parts personnalisées
- [x] `RG-DEP-02` Assiette figée à la création, sans effet rétroactif
- [x] `RG-DEP-03` Possibilité d'exclure le payeur de l'assiette
- [x] `EF-DEP-03` Modifier et supprimer une dépense
- [x] `RG-DEP-04` Historique des modifications conservé — `expense_revisions`, en ajout seul
- [x] `RG-DEP-05` Suppression logique, avec recalcul des soldes
- [x] `EF-DEP-04` Liste des dépenses avec totaux
- [x] `EF-DEP-05` Détail d'une dépense : payeur, participants, part de chacun
- [x] Écrans : dépenses, création de dépense, détail

## Lot 1.8 — Remboursements

**Livré.** C'est la partie la plus sensible du produit : elle est couverte avant tout le
reste, et le jeu de référence du `§6.5` est un test bloquant.

- [x] `§6.2` Répartition au centime avec la règle des plus grands restes — `Repartition`
- [x] `IV-01` Vérifier que la somme des parts égale exactement le montant
- [x] `§6.3` Calcul des soldes — `Soldes`
- [x] `IV-02` Vérifier que la somme des soldes est nulle, journaliser toute violation
  - → journalisé en erreur **et** signalé à l'interface : afficher des chiffres qu'on
    sait faux serait pire que dire qu'ils le sont
- [x] `§6.4` Algorithme d'appariement glouton, tri déterministe des égalités
- [x] `RG-RMB-01` Résultat reproductible à l'identique
- [x] `RG-RMB-02` Aucun solde persisté, recalcul à la demande
- [x] `RG-RMB-03` Les règlements effectués entrent dans le calcul suivant
- [x] `EF-RMB-01` Affichage du solde de chaque membre
- [x] `EF-RMB-02` Liste des règlements proposés
- [x] `RG-CALC-01` Ordre d'affichage identique à l'ordre d'émission
- [x] `EF-RMB-03` Marquer un règlement comme effectué
- [x] `EF-RMB-04` Annuler un marquage
- [ ] `EF-RMB-05` Rappel de sa propre dette **sur le tableau de bord** — l'écran des
      règlements l'affiche, le tableau de bord non : même manque que `RG-UI-02`
- [x] `RG-RMB-04` Avertissement si la somme des soldes n'est pas nulle
- [x] **Test bloquant** : le jeu de référence du `§6.5` produit les deux règlements attendus, dans l'ordre attendu — `JeuDeReferenceTests`
- [x] `RG-TEST-02` Test de l'invariant `IV-02` sur données générées aléatoirement — `SoldesTests`, plusieurs graines
- [x] `NF-QUAL-01` Couverture de 100 % des branches du domaine financier
  - → mesuré par coverlet le 24/08/2026 : `Repartition` et `Soldes` à **100 % de lignes
    et 100 % de branches**. Les services applicatifs `ExpenseService` et
    `SettlementService` sont couverts par les tests d'intégration, hors de cette mesure
- [x] `RG-TEST-01` Interdire toute livraison du domaine financier sans passage du jeu de référence — le test tourne dans `make verif` et en CI
- [ ] `NF-PERF-03` Calcul complet en moins de 50 ms pour 20 membres et 100 dépenses —
      **aucun test ne le mesure** : la case reste décochée plutôt que supposée
- [x] Écran : règlements

## Lot 1.9 — Planning — **abandonné le 21/08/2026**

Abandonné dans ses deux acceptions : ni déroulé horaire de la soirée, ni choix collectif
de la date par vote. La date reste obligatoire à la création et se modifie dans les
paramètres de l'événement — c'est ce que le besoin réel demandait. Le vote de dates
supposait une structure dédiée, l'index unique `(poll_id, member_id)` de `poll_votes`
interdisant de voter sur plusieurs options. L'onglet « Planning » est retiré de la
navigation : quatre onglets subsistent, et la place est prise par la discussion.

`EF-PLN-01` à `EF-PLN-07` sont sans objet. Voir
`docs/superpowers/plans/2026-08-21-achevement-v1-cadrage.md`.

## Lot 1.10 — Fil d'activité

- [ ] `EF-FIL-01` Fil horodaté des actions structurantes
- [ ] `RG-FIL-01` Couvrir les 10 catégories d'événements listées
- [ ] `RG-FIL-02` Lecture seule, non modifiable même par le propriétaire
- [ ] Pagination par curseur — `§8.1`
- [ ] Intégration au tableau de bord

## Lot 1.11 — Notifications

**Transport livré le 25/08/2026** — voir
`docs/superpowers/plans/2026-08-24-notifications-transport.md`. Une notification part du
serveur et arrive sur un appareil, Android comme Web. **Aucun déclencheur métier n'est
branché : personne ne reçoit rien tant que les lignes `EF-NOT-` ci-dessous ne sont pas
cochées.** C'est écrit ici parce qu'un transport livré donne l'impression d'un lot fait.

- [x] Configurer les notifications poussées FCM pour Android et Web — exclusivement pour les notifications, jamais pour les liens, l'authentification, les données ou le temps réel
  - → enregistrement des appareils, `POST`/`DELETE /v1/me/devices`, idempotent et réaffectant
  - → émetteur FCM HTTP v1 sans dépendance nouvelle ; repli console sans clé (règle 5)
  - → mise au rebut des jetons refusés par FCM, `UNREGISTERED` et `INVALID_ARGUMENT`
    seulement : une panne passagère de Google ne doit pas désactiver les appareils
  - → service worker web engendré à la compilation de l'image, et seulement avec la
    configuration Firebase
  - → reste à faire par l'exploitant : déposer la clé de compte de service et poser les
    cinq variables web, voir `docs/comptes-externes.md` §2
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
- [x] `RG-NOT-03` Consentement demandé au moment utile, pas au premier lancement
  - → demandé à l'entrée dans une soirée, jamais au lancement : un refus système ne se
    redemande pas, et demander trop tôt fait refuser par réflexe
- [x] Ouverture du lien profond au tap, application déjà lancée ou démarrée par la
      notification — le second cas est celui qu'on oublie, et c'est le plus fréquent
- [ ] Mettre en place l'ordonnanceur des tâches de fond
- [ ] Écrans : notifications, préférences de notification

## Lot 1.12 — Interface et navigation

- [ ] Écrans de démarrage et de découverte — reportés : ils présentent le produit fini
- [x] `RG-UI-01` Barre inférieure à cinq entrées, le reste sous « Plus »
  - → `IndexedStack` et non reconstruction : changer d'onglet ne doit ni recharger le
    tableau de bord, ni perdre la position de défilement
- [x] Écrans profil et paramètres
- [x] `NF-OFFLINE-01` Consultation du dernier état chargé et file d'attente des écritures
  - → couche générique adossée à `ApiClient`, seul point de sortie réseau : un cache par
    écran et une file par module divergeraient, et chaque module suivant repaierait le
    prix de leur mise en place
  - → la clé d'idempotence est fixée à l'inscription en file, jamais régénérée au rejeu :
    une clé neuve ne serait pas reconnue par le serveur et le rejeu créerait un doublon
  - → la mise en file est déclarée opération par opération : `invitation/rotate` est
    délibérément non idempotent, et un rejeu invaliderait le lien qui vient d'être partagé
  - → panne détectée sur l'échec réel de la requête, jamais par une bibliothèque de
    connectivité : un wifi capté sans Internet — cave, salle des fêtes, portail captif —
    est le cas le plus fréquent pour ce produit, et une telle bibliothèque le déclare
    « connecté »
  - → cache purgé à la déconnexion : il contient le contenu d'événements privés
  - → **limite consignée** : `shared_preferences` ne conviendra plus au fil d'activité
    paginé du lot 1.10 ; les trois unités étant isolées derrière leur interface, en
    changer ne touchera ni `ApiClient` ni un écran
- [ ] `NF-PERF-04` Premier affichage utile en moins de 2,5 s en 4G — mesure, à faire au
  déploiement ; le bundle web pèse 31 Mo en CanvasKit
- [x] `NF-A11Y-03` Libellés sémantiques sur toute action

## Lot 1.13 — Sécurité et conformité

- [ ] `RG-SEC-02` Test de cloisonnement sur chaque endpoint, réponse 404
- [ ] `NF-SEC-02` Aucun secret dans le dépôt
- [ ] `NF-SEC-03` Aucun montant, adresse ou jeton en clair dans les journaux
- [ ] `EF-RGPD-01` Export complet des données au format JSON
- [ ] `EF-RGPD-02` Suppression de compte effective sous 30 jours
- [ ] `RG-RGPD-01` Anonymisation des contributions financières à la suppression
- [ ] `EF-RGPD-03` Rectification des données d'identité
- [ ] `EF-RGPD-04` Retrait du consentement par catégorie
- [ ] `RG-RGPD-02` Documenter le traitement des lignes historiques sans compte, conservées avec leurs références financières
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

**Rédigés le 25/08/2026**, publiés par le site vitrine. Ils décrivent fidèlement le
fonctionnement du service ; ils n'ont **pas** été relus par un juriste, et les identités
de l'éditeur et de l'hébergeur restent à renseigner.

- [x] Conditions générales d'utilisation
- [x] Politique de confidentialité, incluant `RG-RGPD-01`
  - → l'anonymisation des contributions financières à la suppression d'un compte est
    expliquée avec son motif : effacer une dépense fausserait les comptes d'une soirée à
    laquelle d'autres ont participé
  - → le périmètre d'un administrateur est décrit, `RG-RGPD-04` et `RG-ADM-01` compris
- [x] Mentions légales — **valeurs entre crochets à remplacer avant mise en ligne**
- [x] `RG-LEG-01` Mention explicite : PartyPlan ne détient ni ne transfère aucun fonds —
      présente dans le pied de chaque page et développée dans les conditions
- [ ] Fiche de confidentialité Google Play
- [x] Politique de cookies — sans objet et dit comme tel : le site n'en dépose aucun, et
      les polices sont hébergées avec lui
- [ ] Relecture juridique des trois documents
- [ ] Renseigner éditeur, hébergeur et adresses de contact

## Lot 1.16 — Site vitrine

**Nature arrêtée le 25/08/2026** : site **statique**, indexable, qui n'appelle jamais
l'API. C'est la seule surface publique du produit — tout le reste est privé par défaut
(règle 9). Son rôle est le référencement et les mentions légales, puis renvoyer ailleurs :
trois boutons vers Google Play, l'App Store et l'application web
(`partyplan.maxencecoeur.fr`). Elle ne figure donc pas dans les origines CORS de l'API :
lui ouvrir CORS élargirait la surface pour un besoin qui n'existe pas.

- [x] Page d'accueil : proposition de valeur, et les trois boutons de sortie
      (Play Store, App Store, application web)
  - → Play et App Store sont annoncés « bientôt » et ne sont pas des liens : l'application
    n'y est pas publiée, un lien mènerait à une page d'erreur
  - → Poppins est hébergée avec le site : la charger depuis Google transmettrait l'adresse
    IP de chaque visiteur, ce que la politique de confidentialité affirme ne pas faire
  - → captures d'écran à ajouter quand les écrans seront figés
- [x] Pages légales publiées — confidentialité, conditions d'utilisation, mentions légales
  - → **incomplètes par construction** : identité de l'éditeur, hébergeur et adresses de
    contact sont marqués « à compléter », seul l'éditeur peut les fournir
  - → relecture juridique non faite
- [x] Page de support et adresse de contact — l'adresse reste à renseigner
- [ ] Fiche de confidentialité Google Play — dépend de la publication (lot 1.18)
- [ ] Captures d'écran de l'application sur la page d'accueil

## Lot 1.17 — Recette et bêta privée

- [x] Recette du parcours événementiel — `tools/recette/parcours-evenement.py`,
      **84 vérifications**, rejouée le 24/08/2026 contre une API réelle
  - → réécrite ce jour-là : elle exerçait encore le parcours invité sans compte supprimé
    par l'`ADR 0006`, et ne pouvait donc plus passer
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

## Lot 2.2 — Sondages — **livré par anticipation en V1.0**

Remonté depuis V1.1 : les sondages naissent dans le fil de discussion, il aurait fallu
livrer la discussion deux fois pour les ajouter après coup. Décision du 21/08/2026.

- [x] `EF-SDG-01` Sondage à choix unique, 2 à 10 options
- [x] `EF-SDG-02` Voter et changer son vote
- [x] `EF-SDG-03` Résultats avec décompte
- [x] `EF-SDG-04` Clôture d'un sondage
- [x] Écran dédié listant tous les sondages, ouverts d'abord
  - → un sondage porté par un message et remonté par cinquante autres devient
    introuvable : l'écran dédié existe pour cette raison

## Lot 2.3 — Discussion — **livré par anticipation en V1.0**

Remonté depuis V1.1 : c'est la fonction qui remplace le fil de messages du groupe, et
elle occupe l'onglet libéré par l'abandon du planning. Décision du 21/08/2026.

- [x] `EF-MSG-01` Message texte dans l'événement
- [x] `EF-MSG-02` Pièce jointe image — compressée avant envoi
- [x] `EF-MSG-03` Réactions emoji
- [x] `EF-MSG-04` Réponse et mention
- [x] `EF-MSG-05` Suppression de son propre message
- [x] `RG-MSG-01` S'en tenir là : aucune fonction de messagerie généraliste
- [x] Un seul fil par événement, et des dossiers d'épingles en guise de « salons »
  - → à six personnes, des salons multiples se videraient et ce qui compte se perdrait
    dans celui que personne ne lit
  - → aucune épingle privée : une seule notion, donc aucune question à se poser au
    moment d'épingler
- [x] Pagination par curseur, repère de lecture et reprise de position
- [x] Les notifications sont **préparées mais pas envoyées** : mentions et messages
      produisent ce qu'il faut pour notifier au lot 1.11, aucun envoi n'est branché

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
