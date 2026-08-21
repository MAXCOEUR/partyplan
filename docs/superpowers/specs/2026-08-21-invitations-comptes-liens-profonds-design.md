# Invitations avec compte et liens profonds — conception

- Date : 21/08/2026
- Statut : à valider
- Périmètre : premier livrable du parcours invitation → soirée

## 1. Objectif

Un lien ou un QR code d'invitation doit conduire une personne vers la soirée, sur Web,
Android ou iOS. Si elle n'a pas de session, PartyPlan lui demande de se connecter ou de
créer un compte sans perdre l'invitation. Après authentification, le compte rejoint
automatiquement la soirée avec son nom de profil et le statut initial `Unknown`
(`Sans réponse`), puis le tableau de bord de la soirée s'ouvre.

Ce livrable remplace le parcours invité sans compte. Il révise donc explicitement
`CLAUDE.md` règle 7, `EF-INV-04`, `RG-INV-05` et les sections correspondantes du cahier
des charges. Une ADR consacrée à cette décision sera ajoutée avec l'implémentation.

## 2. Hors périmètre

- Le temps réel SignalR est le deuxième livrable. Ce premier livrable conserve les
  lectures REST et l'actualisation manuelle existantes.
- Firebase Cloud Messaging est le troisième livrable. Firebase ne gère ni les liens,
  ni l'authentification, ni les données, ni le temps réel.
- Le lien différé après installation depuis un store n'est pas pris en charge. Sans
  l'application installée, le lien ouvre l'application Web ; après installation, la
  personne peut rouvrir le même lien.
- Aucun fournisseur de deep links tiers n'est ajouté.

## 3. Causes du comportement actuel

1. En développement, l'API fabrique les invitations avec le repli
   `http://localhost:8080`, tandis que `make web` sert Flutter sur le port `5173`.
2. Android ne déclare aucun filtre `https` vérifié et iOS ne possède ni entitlement
   `Associated Domains` ni fichier d'association publié. Le système ne peut donc pas
   remettre `/join/{token}` à l'application installée.
3. `ConnexionPage` et `InscriptionPage` naviguent toujours vers `/` après succès. Le
   chemin d'invitation n'est pas conservé.
4. `AdhesionPage` matérialise encore l'ancien contrat sans compte : elle demande un
   prénom et un statut avant le premier accès à la soirée.
5. `POST /v1/join/{token}` accepte encore un nom libre et peut émettre un jeton invité.

## 4. Décisions structurantes

### 4.1 Identité obligatoire

Les aperçus `GET /v1/join/{token}` et `GET /v1/join/code/{shortCode}` restent publics et
restreints au nom, aux dates, au lieu, à la description et au nombre de participants.
Toutes les adhésions exigent une session de compte valide.

Le serveur choisit le nom du membre à partir du profil du compte. Le client ne transmet
plus de `displayName` ni de `status` à l'adhésion. Le statut créé est toujours
`EventMemberStatus.Unknown`. La présence se modifie ensuite avec l'endpoint existant
`PATCH /v1/events/{eventId}/members/me`.

Le module Events n'accède jamais à la table `users`. Un contrat public
`IUserIdentityLookup` dans le SharedKernel expose uniquement :

```csharp
Task<UserIdentity?> FindAsync(Guid userId, CancellationToken cancellationToken);

public sealed record UserIdentity(Guid Id, string DisplayName);
```

Le module Users implémente ce contrat. Le module Events l'utilise pour copier le nom
actuel dans `event_members.display_name` au moment de l'adhésion. Cette copie reste
intentionnelle : l'historique et les données financières gardent le nom connu au moment
de l'action.

### 4.2 Contrats HTTP

Les lectures publiques ne changent pas :

```http
GET /v1/join/{token}
GET /v1/join/code/{shortCode}
```

Les écritures deviennent authentifiées et sans corps métier :

```http
POST /v1/join/{token}
Authorization: Bearer <access-token>
Idempotency-Key: <uuid>

POST /v1/join/code/{shortCode}
Authorization: Bearer <access-token>
Idempotency-Key: <uuid>
```

La réponse reste minimale :

```json
{
  "eventId": "0198…",
  "memberId": "0198…"
}
```

`guestToken` et `guestTokenExpiresAt` disparaissent de `JoinResult`. La création de
nouveaux jetons invités et `/v1/auth/guest-claim` sont retirés. Les anciennes lignes
`event_members` sans `user_id` ne sont pas supprimées par migration : elles peuvent
porter des données financières historiques. Elles ne permettent simplement plus
d'ouvrir une nouvelle session.

Une adhésion rejouée pour un compte déjà membre est idempotente : elle renvoie les mêmes
`eventId` et `memberId` sans modifier sa présence. Réouvrir un lien ne remet donc jamais
un statut existant à `Sans réponse`.

### 4.3 Retour après authentification

Le chemin d'invitation reste la source de vérité. Aucun jeton d'invitation n'est stocké
dans Firebase, les préférences ou le stockage sécurisé.

Depuis l'aperçu, une personne anonyme choisit :

```text
/connexion?retour=%2Fjoin%2F{token}
/inscription?retour=%2Fjoin%2F{token}
```

Le paramètre `retour` n'accepte qu'un chemin interne commençant par `/join/` ou
`/rejoindre/`. Toute URL absolue, `//host`, route administrative ou autre chemin est
rejeté et remplacé par `/`. Cette liste positive empêche une redirection ouverte après
connexion.

Après connexion ou inscription, l'application revient à l'aperçu. Comme la session est
alors connectée, l'écran lance l'adhésion une fois, affiche un état de progression, puis
utilise `go('/events/{eventId}')`. L'historique ne ramène pas au formulaire de connexion
ni à une adhésion déjà terminée.

Le code court suit exactement le même parcours avec `/rejoindre/{code}`. Le code ne
révèle jamais le jeton long.

### 4.4 État de l'écran d'invitation

L'aperçu conserve sa hiérarchie actuelle : identité de la soirée, date, lieu et nombre
de participants. La zone d'action varie selon la session :

- anonyme : deux actions visibles, `Se connecter` et `Créer un compte` ;
- connecté, non membre : adhésion automatique avec indicateur non bloquant ;
- connecté, déjà membre : ouverture directe de la soirée ;
- adhésions fermées : explication lisible, aucune tentative d'adhésion ;
- lien invalide ou régénéré : message neutre, sans donnée d'événement.

L'ancien `AdhesionPage` prénom → statut et ses routes `/participer` sont supprimés. Le
choix de présence reste dans la section `Ma présence` du tableau de bord.

## 5. Liens Web, Android et iOS

### 5.1 URL canonique

L'URL partagée reste :

```text
https://partyplan.maxencecoeur.fr/join/{token}
```

Le QR code encode strictement la même URL. En développement, `App:PublicBaseUrl` vaut
`http://localhost:5173` avec `make api` + `make web`, et `http://localhost:8080` dans la
pile Docker complète. La valeur vient de la commande de lancement, pas d'un repli caché
différent du serveur Web réellement utilisé.

### 5.2 Web

Le serveur de l'application doit renvoyer `index.html` pour `/join/*` et
`/rejoindre/*`. `go_router` reçoit alors l'URL initiale et construit l'aperçu. Les fichiers
d'association natifs sont servis sans redirection et avec un type JSON :

```text
/.well-known/assetlinks.json
/.well-known/apple-app-site-association
```

### 5.3 Android App Links

L'activité principale déclare un filtre `VIEW`, `BROWSABLE`, `DEFAULT`, HTTPS, hôte
`partyplan.maxencecoeur.fr` et préfixe `/join/`, avec `android:autoVerify="true"`.

`assetlinks.json` associe `fr.maxencecoeur.partyplan` aux empreintes SHA-256 des
certificats réellement utilisés. Le certificat de développement permet la recette
locale sur appareil ; la clé de publication devra être ajoutée avant diffusion sur le
Play Store. Une empreinte inventée ou un fichier générique n'est jamais publié.

### 5.4 iOS Universal Links

Runner reçoit l'entitlement :

```text
applinks:partyplan.maxencecoeur.fr
```

`apple-app-site-association` limite l'association à `/join/*`. Son identifiant combine
le Team ID Apple réel du compte de publication et `fr.maxencecoeur.partyplan`. Le fichier
n'est publié qu'après lecture de ce Team ID dans la configuration de signature ; aucune
valeur fictive n'est acceptée. La vérification iOS de production reste un jalon explicite
tant que le compte Apple et la signature de distribution ne sont pas disponibles ; cela
ne bloque ni le Web ni Android.

Firebase Dynamic Links n'est pas utilisé : le service est arrêté depuis le 25/08/2025.

## 6. Erreurs et reprise

| Situation | Comportement |
|---|---|
| Session expirée pendant l'adhésion | rafraîchissement du jeton existant, puis une seule reprise idempotente |
| Authentification annulée | retour navigateur vers l'aperçu, invitation toujours dans l'URL |
| Invitation régénérée | aperçu neutre `Invitation introuvable ou expirée` |
| Adhésions fermées avant le POST | erreur métier affichée sur l'aperçu, sans redirection |
| Compte suspendu | refus d'authentification existant, invitation conservée |
| API indisponible | état d'erreur avec `Réessayer`, sans perdre le chemin |
| Compte déjà membre | réponse idempotente puis ouverture de la soirée |

L'adhésion ne rejoint pas la file hors ligne : l'application doit connaître l'identité
du membre et l'événement avant d'ouvrir un contenu privé. L'idempotence protège en
revanche les reprises réseau et doubles appuis.

## 7. Sécurité et confidentialité

- L'aperçu public reste volontairement pauvre et n'est jamais mis en cache depuis un
  code court.
- Le POST exige un compte authentifié et le cloisonnement `User → EventMember → Event`
  reste la seule porte vers le contenu.
- Le nom vient du module Users par interface publique, jamais du corps HTTP.
- Le paramètre `retour` est validé par liste positive pour éviter les redirections
  ouvertes.
- App Links et Universal Links reposent sur l'association HTTPS du domaine ; aucun
  schéma personnalisé interceptable n'est ajouté.
- Une invitation régénérée invalide immédiatement le lien et le code précédents.

## 8. Tests et critères d'acceptation

### API

- un POST anonyme par jeton ou code reçoit `401` ;
- un compte rejoint avec le `DisplayName` de son profil et le statut `Unknown` ;
- le corps HTTP ne permet pas d'imposer un autre nom ou statut ;
- un rejeu renvoie le même membre sans doublon et sans modifier sa présence ;
- deux comptes utilisant le même lien créent deux membres distincts ;
- un lien régénéré, un code invalide et des adhésions fermées gardent leurs refus ;
- les anciens membres sans compte et leurs relations financières survivent à la
  migration, mais aucun nouveau jeton invité n'est émis.

### Flutter

- l'ouverture directe de `/join/{token}` affiche l'aperçu sans session ;
- connexion et inscription reçoivent un retour encodé et reviennent à l'invitation ;
- un retour externe ou non autorisé est remplacé par `/` ;
- aucune saisie de prénom ou de statut n'apparaît avant l'entrée dans la soirée ;
- l'adhésion réussie ouvre `/events/{eventId}` avec `go` ;
- un membre existant ouvre la soirée sans changement de présence ;
- lien invalide, arrivées fermées et panne réseau ont chacun leur état explicite ;
- les parcours par jeton et code court sont équivalents.

### Plateformes

- `adb shell am start` avec l'URL canonique ouvre l'application Android installée sur
  `/join/{token}` ; sans application, la même URL ouvre le Web ;
- les outils de vérification Android confirment `assetlinks.json` ;
- iOS ouvre le lien universel après association du Team ID et de la signature ;
- une requête HTTP directe sur `/join/{token}` reçoit bien le shell Flutter Web et non
  une 404 du reverse proxy.

## 9. Ordre de livraison

1. Réviser la documentation et ajouter l'ADR `compte obligatoire pour rejoindre`.
2. Modifier le contrat API et migrer sans supprimer les membres historiques.
3. Conserver et valider le retour d'authentification côté Flutter.
4. Remplacer `AdhesionPage` par l'adhésion automatique depuis l'aperçu.
5. Corriger les URL de développement et le repli Web des routes profondes.
6. Configurer et vérifier Android App Links.
7. Configurer iOS Universal Links, avec jalon de signature clairement signalé si les
   identifiants Apple ne sont pas encore disponibles.
8. Exécuter les suites API et Flutter, l'analyse statique et les recettes de liens.

Une fois ce livrable validé et vérifié, une spécification séparée couvrira SignalR. La
troisième couvrira exclusivement Firebase Cloud Messaging.
