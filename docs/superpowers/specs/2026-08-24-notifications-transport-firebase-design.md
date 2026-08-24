# Notifications poussées — le transport

**Date** : 24/08/2026. **Lot** : 1.11, ouverture partielle.
**Décision de périmètre** : le transport seul.

## Objectif

Qu'une notification partie du serveur arrive sur un téléphone. Rien de plus.

Aucun déclencheur métier n'est branché : après ce sous-projet, PartyPlan sait envoyer une
notification mais n'en envoie aucune de lui-même. C'est délibéré — le transport est ce qui
demande un compte externe, un enregistrement d'appareil et une permission système, donc ce
qui casse. Les six déclencheurs de `EF-NOT-01` à `EF-NOT-06` sont ensuite du code métier
ordinaire, vérifiable sans téléphone.

## Hors périmètre, explicitement

| Écarté | Référence |
|---|---|
| Les six déclencheurs métier | `EF-NOT-01` à `EF-NOT-06` |
| Plage de silence 22 h – 8 h | `RG-NOT-01` |
| Regroupement au quart d'heure | `RG-NOT-02` |
| Écrans de préférences par catégorie, sourdine d'un événement | `EF-NOT-07`, `EF-NOT-08` |
| Ordonnanceur de tâches de fond | lot 1.11 |
| Repli courriel | `EF-NOT-09`, V1.1 |
| iOS | V1.2 — exige APNs et un compte développeur Apple |

Les colonnes qui servent ces règles existent déjà : `notifications.scheduled_for` pour le
silence, `event_mute_settings` pour la sourdine, `notification_preferences` pour les
catégories. Aucune migration n'est attendue.

## État de départ

- `IPushSender` : contrat public, déjà écrit, **inchangé par ce sous-projet**.
- `ConsolePushSender` : journalise au lieu d'envoyer. Reste en place.
- Tables `notifications` et `push_devices` : créées à la migration initiale.
- `NotificationsModule` : coquille vide, ni service ni endpoint.
- Projet Firebase `partyplan-99106`, avec l'application Android
  `fr.maxencecoeur.partyplan` et une application Web enregistrées le 24/08/2026.
- Clé de compte de service créée le 24/08/2026, hors dépôt, mode 600.
- Clé VAPID du push web engendrée le 24/08/2026, vérifiée conforme. Elle n'était pas
  obtenable par le CLI : aucune API ne l'expose, seule la console la produit. Le plan reste
  néanmoins ordonné pour livrer Android d'abord — c'est la bonne façon de séquencer un
  transport dont une moitié dépend d'un tiers.

## Architecture

### Frontières — `ADR 0002`

Le module `Notifications` possède `notifications` et `push_devices`, et **mappe ses propres
endpoints**. La route reste `/v1/me/devices` pour l'appelant, mais elle est déclarée par
`NotificationsModule.MapEndpoints` et non par `MeEndpoints` : faire lire `push_devices` par
le module `Users` violerait la règle 6, et un contrat inter-modules pour deux endpoints
serait une cérémonie sans objet.

`IPushSender` demeure le seul point de contact des autres modules. Le code métier du lot
1.11 s'y branchera sans savoir que Firebase existe.

### Choix de l'émetteur, une fois au démarrage

```
clé de compte de service lisible → FirebasePushSender
absente ou illisible             → ConsolePushSender
```

C'est la règle 5 tenue par construction : sans clé, l'application entière fonctionne et les
notifications se lisent dans la console (`NF-DEV-04`). Une clé illisible bascule sur la
console **avec un avertissement au démarrage**, plutôt que de faire échouer le démarrage :
une notification perdue ne vaut pas une instance à l'arrêt.

### Envoi, sans dépendance nouvelle

FCM HTTP v1 exige un jeton OAuth2, obtenu en échangeant un JWT signé par la clé du compte
de service.

1. JWT RS256 — `Microsoft.IdentityModel.JsonWebTokens`, déjà présent, `aud` =
   `https://oauth2.googleapis.com/token`, `scope` =
   `https://www.googleapis.com/auth/firebase.messaging`
2. Échange sur `oauth2.googleapis.com/token`, jeton **mis en cache jusqu'à son expiration
   moins soixante secondes**
3. `POST fcm.googleapis.com/v1/projects/partyplan-99106/messages:send`

Le paquet officiel `FirebaseAdmin` tirerait une dizaine d'assemblys Google pour ce seul
appel et élargirait la surface analysée par `NF-SEC-05`. Le dépôt a déjà tranché deux fois
dans ce sens : la RFC 6238 était écrite à la main, et `GoogleIdentityVerifier` valide les
jetons Google avec `Microsoft.IdentityModel` sans SDK Google. Environ 120 lignes contre une
dépendance lourde sur un chemin d'authentification.

`Directory.Packages.props` ne gagne aucune entrée.

### Traitement des échecs

| Réponse FCM | Traitement |
|---|---|
| `UNREGISTERED`, `INVALID_ARGUMENT` sur le jeton | `push_devices.disabled_at` posé. Un téléphone réinstallé ne doit pas faire échouer les envois indéfiniment. |
| `UNAVAILABLE`, `INTERNAL` | journalisé, non réessayé ici. Le rejeu appartient à l'ordonnanceur du lot 1.11. |
| Échec d'obtention du jeton OAuth2 | journalisé en erreur, envoi abandonné. |

Dans tous les cas, **`SendAsync` ne lève pas**. Le contrat l'exige déjà : « perdre l'avis
vaut mieux que perdre la dépense qui l'a déclenché ».

Le jeton d'appareil est tronqué en journal — c'est une donnée d'identification
(`NF-SEC-03`), et `ConsolePushSender` le fait déjà.

## Enregistrement d'un appareil

```
POST   /v1/me/devices           { token, platform }   → 204
DELETE /v1/me/devices/{token}                         → 204
```

Authentification requise ; un appelant anonyme reçoit 401.

**Idempotent sur le jeton.** Un jeton FCM est renvoyé par le système à chaque lancement :
la ligne existante voit son `last_seen_at` mis à jour et son `disabled_at` effacé, sans
créer de doublon. Sans cette idempotence, `push_devices` grossirait à chaque ouverture de
l'application et chaque notification partirait en plusieurs exemplaires.

**Un jeton déjà rattaché à un autre compte est réaffecté.** C'est le cas du téléphone
prêté et celui de la déconnexion suivie d'une autre connexion. Le refuser laisserait les
notifications d'un compte arriver chez quelqu'un d'autre.

`platform` est contraint à `android` ou `web` ; toute autre valeur est refusée en 400. La
colonne est du texte libre en base, mais un fourre-tout non validé finit par contenir trois
orthographes de la même plateforme.

**La déconnexion supprime le jeton de l'appareil courant.** Côté client, avant de purger la
session — sinon l'appel n'est plus authentifié. C'est le pendant nécessaire de la
réaffectation : un téléphone rendu ne doit plus rien recevoir.

## Côté application

`firebase_messaging`, Android et Web.

**Consentement au moment utile** — `RG-NOT-03`. La demande est faite à l'entrée dans une
soirée, jamais au lancement : c'est là qu'on a pour la première fois quelque chose à être
notifié. Un refus est respecté et n'est pas redemandé. La permission accordée, le jeton part
vers `/v1/me/devices`, et à chaque rafraîchissement de jeton également.

**Lien profond au tap.** La notification porte une route applicative, le client l'ouvre par
`go_router`. Deux chemins : application déjà lancée, et application démarrée par la
notification — le second est celui qu'on oublie, et le seul qui compte pour un rappel reçu
la veille.

**Web** : `firebase-messaging-sw.js` engendré à la compilation depuis un gabarit, avec la
configuration substituée. Un service worker ne peut pas lire un `--dart-define`, et deux
sources de configuration divergeraient. `nginx.conf` le sert à la racine sans cache
agressif : un service worker figé en cache est un service worker qu'on ne peut plus
corriger.

## Configuration : trois natures, trois emplacements

C'est le point qui a le plus de conséquences pratiques.

| Valeur | Nature | Emplacement |
|---|---|---|
| Clé de compte de service | **exécution** | fichier monté, chemin en variable |
| Config Firebase Web + clé VAPID | **compilation** | variables GitHub Actions → `ARG` → `--dart-define` |
| `google-services.json` | **compilation Android** | poste de développement, ou CI de signature |

`flutter build web` produit des fichiers statiques : la configuration web est figée dans
l'image, exactement comme `API_BASE_URL` l'est déjà. Elle **ne peut pas** se régler dans le
compose du NAS. Le mécanisme existe, il n'en est pas créé de nouveau.

### Un chemin, pas un contenu

`PushOptions.FirebaseServiceAccountJson` attendait le JSON sur une seule ligne. Remplacé par
`FirebaseServiceAccountPath` :

```yaml
    volumes:
      - ./secrets/firebase.json:/run/secrets/firebase.json:ro
    environment:
      Push__FirebaseServiceAccountPath: /run/secrets/firebase.json
```

Motif : le déploiement se fait sur un NAS **sans fichier `.env`**, en remplaçant les valeurs
directement dans le compose. Y coller 2 300 caractères de JSON contenant une clé privée PEM
est fonctionnel mais piégeux — une virgule mal échappée et le conteneur ne démarre plus sans
que rien ne l'explique. Le fichier se dépose tel que Firebase le donne, sans retouche. Un
seul mécanisme pour le local et pour la production. Rien ne consommait encore l'ancienne
option : la renommer ne casse rien.

### Le dépôt ne porte aucun de ces fichiers

`google-services.json` est absent du dépôt et le greffon Google Services n'est appliqué
**que s'il est présent**. Sans lui, l'application compile et tourne, sans notifications.
C'est la règle 5 à la lettre : un clone frais est utilisable sans compte Firebase. Le prix
est une condition dans `build.gradle.kts`, et il est assumé.

## Fichiers touchés

**Serveur**

- `api/src/PartyPlan.Infrastructure/Notifications/FirebasePushSender.cs` — nouveau
- `api/src/PartyPlan.Infrastructure/Notifications/ConsolePushSender.cs` — `PushOptions`
  renommé, avertissement de clé illisible
- `api/src/PartyPlan.Infrastructure/DependencyInjection.cs` — choix de l'émetteur,
  `AddHttpClient` pour FCM
- `api/src/PartyPlan.Modules.Notifications/Application/DeviceService.cs` — nouveau
- `api/src/PartyPlan.Modules.Notifications/Endpoints/DeviceEndpoints.cs` — nouveau
- `api/src/PartyPlan.Modules.Notifications/Persistence/INotificationsDbContext.cs` —
  exposer `PushDevices`
- `api/src/PartyPlan.Modules.Notifications/NotificationsModule.cs` — enregistrement

**Application**

- `app/pubspec.yaml` — `firebase_core`, `firebase_messaging`
- `app/lib/core/notifications/` — service d'enregistrement, demande de permission,
  ouverture du lien profond
- `app/lib/core/network/appareils_api.dart` — nouveau
- `app/lib/features/evenement/tableau_de_bord_page.dart` — demande du consentement à la
  première ouverture d'un tableau de bord d'événement. C'est l'endroit exact : on vient
  d'entrer dans une soirée, donc d'acquérir quelque chose à être notifié, et la page est
  déjà composée de sections autonomes
- `app/android/app/build.gradle.kts` — greffon conditionnel
- `app/web/firebase-messaging-sw.js.template`, `app/Dockerfile`, `app/nginx.conf`

**Configuration et documentation**

- `.gitignore` — fait le 24/08/2026
- `.env.example`, `infra/compose/.env.example`
- `infra/compose/compose.yml`, `compose.example.yml`, `compose.nas.example.yml`
- `.github/workflows/docker.yml` — cinq `ARG` de configuration web
- `docs/comptes-externes.md` — procédure Firebase de bout en bout
- `docs/exploitation.md` — la clé au tableau des secrets, et ce que sa perte implique
- `docs/roadmap.md` — ouverture partielle du lot 1.11
- `docs/api/openapi.json` — régénéré

## Vérification

| Niveau | Ce qui est vérifié |
|---|---|
| Unitaire | Corps du message FCM conforme à HTTP v1 ; mise au rebut sur `UNREGISTERED` ; cache du jeton OAuth2 et son renouvellement ; troncature du jeton en journal |
| Unitaire | Absence de clé → `ConsolePushSender` ; clé illisible → `ConsolePushSender` **et** avertissement, jamais d'échec au démarrage |
| Intégration | Les deux endpoints ; idempotence sur rejeu du même jeton ; réaffectation entre comptes ; `platform` inconnue refusée ; appelant anonyme à 401 |
| Flutter | Consentement demandé à l'entrée dans une soirée et pas au lancement ; refus non redemandé ; jeton transmis à l'obtention et au rafraîchissement ; déconnexion qui retire le jeton |
| Réel | **Une notification atteint un téléphone.** C'est la seule preuve qui compte pour un transport, et aucun test ne la remplace. |

Aucun test n'appelle FCM : la frontière est le client HTTP, substitué. Les tests tournent
sans réseau, comme l'exige `NF-DEV-10`.

## Risques

| Risque | Traitement |
|---|---|
| Le push web exige HTTPS | `localhost` est excepté par les navigateurs ; la production est en HTTPS derrière le proxy |
| Clé de compte de service compromise | Elle permet d'envoyer à tous les appareils enregistrés, rien de plus : pas de lecture de données. Rotation documentée dans `docs/exploitation.md` |
| Notifications web sur PWA iOS | Limitation connue, `R-06`. Hors périmètre avec iOS |
| Jeton FCM long en base | `push_devices.token` est du `text` PostgreSQL, sans limite pratique. **Aucune migration** : borner cette colonne à une longueur devinée serait le seul vrai risque, Google n'en garantissant aucune |

## Ce que ce sous-projet ne prouve pas

À son terme, aucune notification ne part d'elle-même. Un utilisateur qui accorde la
permission ne recevra rien jusqu'à ce que les déclencheurs soient écrits. La feuille de
route doit le dire, sans quoi le lot 1.11 paraîtra fait.
