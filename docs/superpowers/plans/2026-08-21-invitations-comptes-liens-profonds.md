# Invitations avec compte et liens profonds — plan d’implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire fonctionner le parcours lien ou QR → authentification → adhésion automatique → soirée sur Web, Android et iOS, avec un compte obligatoire, le nom du profil et le statut initial `Unknown`.

**Architecture:** Les aperçus d’invitation restent publics, mais les deux POST d’adhésion exigent un JWT de compte et récupèrent le nom courant via un contrat inter-modules minimal implémenté par Users. Flutter conserve l’invitation dans un paramètre `retour` interne validé, rejoint automatiquement après authentification, puis ouvre la soirée. Le domaine HTTPS canonique est associé aux applications par Android App Links et iOS Universal Links ; Firebase, SignalR et les notifications restent hors de ce plan.

**Tech Stack:** ASP.NET Core 10, EF Core 10, xUnit/Shouldly, Flutter 3.38/Dart 3.10, Riverpod 3, go_router 17, nginx 1.27, Android App Links, iOS Universal Links.

**Spec:** `docs/superpowers/specs/2026-08-21-invitations-comptes-liens-profonds-design.md`

## Global Constraints

- Lire `CLAUDE.md`, l’ADR 0002, l’ADR 0003, l’ADR 0005 et la spécification avant toute modification.
- Respecter le cloisonnement `User → EventMember → Event`; un rôle plateforme ne contourne jamais l’appartenance.
- Un compte est obligatoire pour toute nouvelle adhésion ; aucun nouveau jeton invité n’est émis.
- Le serveur choisit `DisplayName`; le client ne transmet ni nom ni statut lors de l’adhésion.
- Une nouvelle adhésion commence avec `EventMemberStatus.Unknown`; un rejeu ne modifie jamais le statut existant.
- Le code court ne révèle jamais le jeton long et garde sa limitation de débit.
- Le paramètre `retour` n’accepte que `/join/{token}` et `/rejoindre/{code}` sans autorité, schéma, fragment ni autre route.
- L’URL canonique de production reste `https://partyplan.maxencecoeur.fr/join/{token}`.
- Firebase n’est utilisé dans aucun fichier de ce plan.
- SignalR n’est utilisé dans aucun fichier de ce plan.
- Les lignes historiques `event_members.user_id IS NULL` et leurs références financières ne sont pas supprimées.
- Préserver les modifications locales existantes ; inspecter le diff de chaque fichier avant édition et utiliser `git commit --only` avec les chemins de la tâche.
- Appliquer strictement RED → GREEN → REFACTOR : chaque test comportemental doit échouer pour la raison attendue avant le code produit.

## File Map

| File | Responsibility |
|---|---|
| `docs/adr/0006-compte-obligatoire-pour-rejoindre.md` | Décision qui remplace officiellement le mode invité sans compte |
| `api/src/PartyPlan.SharedKernel/Contracts/IUserIdentityLookup.cs` | Lecture inter-modules minimale de l’identité affichée |
| `api/src/PartyPlan.Modules.Users/Application/UserIdentityLookup.cs` | Implémentation Users du contrat d’identité |
| `api/src/PartyPlan.Modules.Events/Application/JoinService.cs` | Adhésion authentifiée, nom serveur, statut initial et rejeu |
| `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs` | Contrats HTTP d’adhésion sans corps, protégés par compte |
| `api/src/PartyPlan.Api/Setup/AuthenticationSetup.cs` | Politique par défaut exigeant une identité de compte |
| `app/lib/app/retour_auth.dart` | Validation et construction du retour interne après authentification |
| `app/lib/app/router.dart` | Propagation du retour et suppression des routes `/participer` |
| `app/lib/features/rejoindre/apercu_invitation_page.dart` | Actions auth et adhésion automatique |
| `app/lib/core/network/evenements_api.dart` | POST d’adhésion sans nom, statut ni stockage invité |
| `app/web/.well-known/assetlinks.json` | Association HTTPS Android avec le certificat réel connu |
| `app/ios/Runner/Runner.entitlements` | Domaine associé iOS côté application |

---

### Task 1: Réviser la décision produit et les exigences

**Files:**
- Create: `docs/adr/0006-compte-obligatoire-pour-rejoindre.md`
- Modify: `CLAUDE.md`
- Modify: `docs/cahier-des-charges.md`
- Modify: `docs/domaine.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-08-20-ecrans-evenementiels-design.md`

**Interfaces:**
- Consumes: la décision approuvée dans la spécification du 21/08/2026.
- Produces: règles documentaires cohérentes utilisées par toutes les tâches suivantes.

- [x] **Step 1: Écrire l’ADR accepté**

Créer l’ADR 0006 avec les décisions exactes suivantes : aperçu public restreint, compte obligatoire avant POST, nom provenant du profil, statut initial `Unknown`, App/Universal Links directs, SignalR pour le temps réel et FCM uniquement pour les notifications.

- [x] **Step 2: Remplacer les exigences contradictoires**

Dans `CLAUDE.md`, remplacer la règle « Invité sans compte » par « Compte obligatoire pour rejoindre ». Dans le cahier des charges, réviser `EF-INV-04`, `RG-INV-05`, `EF-AUTH-11`, la matrice des rôles, les routes et le critère global 14. Conserver `event_members.user_id` nullable uniquement pour l’historique financier.

- [x] **Step 3: Vérifier la cohérence documentaire**

Run:

```bash
rg -n "sans compte|guest/upgrade|guest-claim|prénom puis statut|trois interactions" \
  CLAUDE.md docs/cahier-des-charges.md docs/domaine.md docs/roadmap.md \
  docs/superpowers/specs/2026-08-20-ecrans-evenementiels-design.md
git diff --check -- CLAUDE.md docs/adr/0006-compte-obligatoire-pour-rejoindre.md \
  docs/cahier-des-charges.md docs/domaine.md docs/roadmap.md \
  docs/superpowers/specs/2026-08-20-ecrans-evenementiels-design.md
```

Expected: aucune exigence active ne promet une nouvelle adhésion sans compte ; les mentions historiques sont explicitement qualifiées comme telles ; `git diff --check` sort avec le code 0.

- [x] **Step 4: Committer uniquement la documentation**

```bash
git commit --only CLAUDE.md docs/adr/0006-compte-obligatoire-pour-rejoindre.md \
  docs/cahier-des-charges.md docs/domaine.md docs/roadmap.md \
  docs/superpowers/specs/2026-08-20-ecrans-evenementiels-design.md \
  -m "docs(invitation): exiger un compte pour rejoindre"
```

### Task 2: Rendre l’adhésion API authentifiée et pilotée par le profil

**Files:**
- Create: `api/src/PartyPlan.SharedKernel/Contracts/IUserIdentityLookup.cs`
- Create: `api/src/PartyPlan.Modules.Users/Application/UserIdentityLookup.cs`
- Modify: `api/src/PartyPlan.Modules.Users/UsersModule.cs`
- Modify: `api/src/PartyPlan.Modules.Events/Application/JoinService.cs`
- Modify: `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs`
- Modify: `api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs`

**Interfaces:**
- Consumes: `ICurrentUser.UserId`, `IUsersDbContext.Users`, `EventMemberStatus.Unknown`.
- Produces: `IUserIdentityLookup.FindAsync(Guid, CancellationToken)` et deux POST d’adhésion sans corps métier retournant `JoinResult(Guid EventId, Guid MemberId)`.

- [x] **Step 1: Écrire les tests d’intégration rouges**

Ajouter ou remplacer les scénarios dans `EvenementsTests` :

```csharp
[Fact]
public async Task Une_session_est_obligatoire_pour_rejoindre()
{
    var organisateur = await CompteAsync();
    var (_, jeton, code) = await CreerAsync(organisateur, "Privée");
    using var anonyme = fixture.CreateClient();

    (await RejoindreBrutAsync(anonyme, $"/v1/join/{jeton}"))
        .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    (await RejoindreBrutAsync(anonyme, $"/v1/join/code/{code}"))
        .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
}

[Fact]
public async Task Le_compte_rejoint_avec_son_nom_et_sans_reponse()
{
    var organisateur = await CompteAsync();
    var (eventId, jeton, _) = await CreerAsync(organisateur, "Barbecue");
    var lea = await CompteAsync("Léa Martin");

    var adhesion = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());
    adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

    var resultat = (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
    resultat.TryGetProperty("guestToken", out _).ShouldBeFalse();

    var membres = await MembresAsync(organisateur, eventId);
    var membre = membres.EnumerateArray().Single(m => m.GetProperty("displayName").GetString() == "Léa Martin");
    membre.GetProperty("status").GetString().ShouldBe("Unknown");
}
```

Adapter `CompteAsync(string nomAffiche = "Organisateur")` et remplacer l’ancien helper
par cette interface exacte :

```csharp
internal static Task<HttpResponseMessage> RejoindreBrutAsync(
    HttpClient client,
    string chemin,
    string? cle = null)
```

Il construit un POST vers `chemin` avec `Content = null` et ajoute
`Idempotency-Key` seulement quand `cle` n’est pas nulle. Ne pas inspecter un mock.

- [x] **Step 2: Lancer les tests et constater RED**

Run:

```bash
dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj \
  --filter 'FullyQualifiedName~EvenementsTests'
```

Expected: le POST anonyme est encore accepté et/ou le POST sans ancien `JoinBody` échoue ; le test du nom serveur ne peut pas passer.

- [x] **Step 3: Ajouter le contrat inter-modules et son implémentation**

Créer :

```csharp
namespace PartyPlan.SharedKernel.Contracts;

public sealed record UserIdentity(Guid Id, string DisplayName);

public interface IUserIdentityLookup
{
    Task<UserIdentity?> FindAsync(Guid userId, CancellationToken cancellationToken);
}
```

Puis implémenter `UserIdentityLookup(IUsersDbContext db)` dans Users par une projection EF sans suivi vers `UserIdentity`, limitée aux comptes non supprimés. Enregistrer `IUserIdentityLookup` dans `UsersModule`.

- [x] **Step 4: Simplifier JoinService et les endpoints**

Remplacer les signatures par :

```csharp
Task<Result<JoinResult>> RejoindreAsync(string token, CancellationToken cancellationToken)
Task<Result<JoinResult>> RejoindreParCodeAsync(string? code, CancellationToken cancellationToken)
```

Dans la méthode privée : exiger `currentUser.UserId`, lire `UserIdentity`, rechercher le membre par `UserId`, renvoyer l’existant sans modifier son statut, puis créer un membre avec `DisplayName = identity.DisplayName` et `Status = EventMemberStatus.Unknown`. Retirer `ITokenService`, `displayName`, `statut`, `arrivee` et les champs invités de `JoinResult`.

Supprimer `JoinBody`. Les deux POST appellent le service sans corps, gardent `RequireIdempotency()`, gardent la limitation du code court et ajoutent `RequireAuthorization()`.

- [x] **Step 5: Vérifier GREEN et les mutations importantes**

Ajouter les tests : même compte + nouvelle clé → même `memberId` et présence inchangée ; même clé → réponse rejouée ; deux comptes → deux membres ; compte supprimé/introuvable → refus ; code court inconnu → 404 ; arrivées fermées → 422.

Run:

```bash
dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj \
  --filter 'FullyQualifiedName~EvenementsTests'
```

Expected: tous les tests `EvenementsTests` réussissent.

- [x] **Step 6: Committer le contrat API**

```bash
git commit --only \
  api/src/PartyPlan.SharedKernel/Contracts/IUserIdentityLookup.cs \
  api/src/PartyPlan.Modules.Users/Application/UserIdentityLookup.cs \
  api/src/PartyPlan.Modules.Users/UsersModule.cs \
  api/src/PartyPlan.Modules.Events/Application/JoinService.cs \
  api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs \
  api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs \
  -m "feat(invitation): rejoindre avec son compte"
```

### Task 3: Fermer l’ancien accès invité sans détruire l’historique

**Files:**
- Delete: `api/src/PartyPlan.SharedKernel/Contracts/IGuestMembershipLinking.cs`
- Delete: `api/src/PartyPlan.Modules.Events/Application/GuestMembershipLinking.cs`
- Delete: `api/tests/PartyPlan.IntegrationTests/ConversionInviteTests.cs`
- Modify: `api/src/PartyPlan.SharedKernel/Abstractions/ICurrentUser.cs`
- Modify: `api/src/PartyPlan.SharedKernel/Contracts/ITokenService.cs`
- Modify: `api/src/PartyPlan.Infrastructure/Identity/CurrentUser.cs`
- Modify: `api/src/PartyPlan.Infrastructure/Persistence/EventScopePrimer.cs`
- Modify: `api/src/PartyPlan.Modules.Auth/Application/TokenService.cs`
- Modify: `api/src/PartyPlan.Modules.Events/EventsModule.cs`
- Modify: `api/src/PartyPlan.Modules.Events/Application/AttendanceService.cs`
- Modify: `api/src/PartyPlan.Modules.Events/Application/EventService.cs`
- Modify: `api/src/PartyPlan.Modules.Events/Application/EventMembership.cs`
- Modify: `api/src/PartyPlan.SharedKernel/Contracts/IEventMembership.cs`
- Modify: `api/src/PartyPlan.Modules.Users/Contracts/Requests.cs`
- Modify: `api/src/PartyPlan.Modules.Users/Endpoints/AuthEndpoints.cs`
- Modify: `api/src/PartyPlan.Api/Setup/AuthenticationSetup.cs`
- Modify: `api/tests/PartyPlan.IntegrationTests/EventScopeIsolationTests.cs`
- Modify: `api/tests/PartyPlan.IntegrationTests/Infrastructure/TestTokens.cs`
- Modify: `api/tests/PartyPlan.UnitTests/OwnershipTransferTests.cs`

**Interfaces:**
- Consumes: adhésion de compte livrée par Task 2.
- Produces: toute route protégée exige `ClaimTypes.NameIdentifier`; aucun service ne crée ou rattache une session invitée.

- [x] **Step 1: Écrire le test rouge du jeton invité historique**

Dans `EventScopeIsolationTests`, conserver `TestTokens.ForGuest(eventId, memberId)` le temps du RED et vérifier qu’un ancien jeton signé reçoit `401` sur `GET /v1/events/{eventId}` et `POST /v1/join/{token}`.

- [x] **Step 2: Lancer le test et constater RED**

```bash
dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj \
  --filter 'FullyQualifiedName~EventScopeIsolationTests'
```

Expected: le jeton invité est encore considéré comme authentifié et atteint au moins une route.

- [x] **Step 3: Exiger un identifiant de compte dans la politique par défaut**

Dans `AuthenticationSetup`, construire la politique par défaut avec :

```csharp
new AuthorizationPolicyBuilder()
    .RequireAuthenticatedUser()
    .RequireClaim(ClaimTypes.NameIdentifier)
    .Build();
```

Conserver les schémas et politiques administratives existants. Vérifier que les jetons d’accès de compte portent déjà `ClaimTypes.NameIdentifier`.

- [x] **Step 4: Retirer le code de création et de conversion invité**

Supprimer `CreateGuestToken`, les claims `GuestEventId`/`MemberId`, les propriétés invitées d’`ICurrentUser`, le contrat et l’implémentation de rattachement, l’endpoint `/auth/guest-claim` et les DTO correspondants. Simplifier `EventScopePrimer`, `AttendanceService` et `EventService` pour ne retrouver le membre courant que par `UserId`.

Simplifier aussi `EventMembership.FindCurrentAsync` pour ne chercher que
`currentUser.UserId` et corriger la documentation d’`IEventMembership` : les lignes
historiques sans compte restent listables, mais ne peuvent plus représenter l’appelant.

Ne pas rendre `EventMember.UserId` non nullable et ne pas produire de migration qui supprime des lignes historiques.

- [x] **Step 5: Réécrire les tests qui exprimaient l’ancien produit**

Remplacer les tests d’invités par des scénarios à deux comptes. Supprimer `ConversionInviteTests.cs`, désormais contradictoire. Dans `OwnershipTransferTests`, garder la règle « seule une cible avec `UserId` peut devenir propriétaire » comme protection des lignes historiques, sans créer de nouvelle adhésion anonyme.

- [x] **Step 6: Vérifier GREEN sur Auth, Events et isolation**

```bash
dotnet test api/PartyPlan.slnx \
  --filter 'FullyQualifiedName~EvenementsTests|FullyQualifiedName~EventScopeIsolationTests|FullyQualifiedName~CompteEtAdministrationTests|FullyQualifiedName~OwnershipTransferTests'
```

Expected: tous les tests filtrés réussissent ; aucune référence compilée ne dépend de `IGuestMembershipLinking` ou `CreateGuestToken`.

- [x] **Step 7: Committer le retrait invité**

```bash
git commit --only \
  api/src/PartyPlan.SharedKernel/Contracts/IGuestMembershipLinking.cs \
  api/src/PartyPlan.Modules.Events/Application/GuestMembershipLinking.cs \
  api/tests/PartyPlan.IntegrationTests/ConversionInviteTests.cs \
  api/src/PartyPlan.SharedKernel/Abstractions/ICurrentUser.cs \
  api/src/PartyPlan.SharedKernel/Contracts/ITokenService.cs \
  api/src/PartyPlan.Infrastructure/Identity/CurrentUser.cs \
  api/src/PartyPlan.Infrastructure/Persistence/EventScopePrimer.cs \
  api/src/PartyPlan.Modules.Auth/Application/TokenService.cs \
  api/src/PartyPlan.Modules.Events/EventsModule.cs \
  api/src/PartyPlan.Modules.Events/Application/AttendanceService.cs \
  api/src/PartyPlan.Modules.Events/Application/EventService.cs \
  api/src/PartyPlan.Modules.Events/Application/EventMembership.cs \
  api/src/PartyPlan.SharedKernel/Contracts/IEventMembership.cs \
  api/src/PartyPlan.Modules.Users/Contracts/Requests.cs \
  api/src/PartyPlan.Modules.Users/Endpoints/AuthEndpoints.cs \
  api/src/PartyPlan.Api/Setup/AuthenticationSetup.cs \
  api/tests/PartyPlan.IntegrationTests/EventScopeIsolationTests.cs \
  api/tests/PartyPlan.IntegrationTests/Infrastructure/TestTokens.cs \
  api/tests/PartyPlan.UnitTests/OwnershipTransferTests.cs \
  -m "refactor(auth): retirer les sessions invitées"
```

### Task 4: Conserver un retour d’authentification sûr

**Files:**
- Create: `app/lib/app/retour_auth.dart`
- Create: `app/test/app/retour_auth_test.dart`
- Modify: `app/lib/app/router.dart`
- Modify: `app/lib/features/auth/connexion_page.dart`
- Modify: `app/lib/features/auth/inscription_page.dart`
- Modify: `app/test/features/connexion_test.dart`
- Modify: `app/test/router_test.dart`

**Interfaces:**
- Consumes: routes `/join/{token}`, `/rejoindre/{code}`, `sessionProvider`.
- Produces: `RetourAuth.destination(String?)`, `RetourAuth.versConnexion(String)` et `RetourAuth.versInscription(String)`.

- [x] **Step 1: Écrire les tests unitaires rouges de validation**

```dart
test('accepte uniquement les deux formes d’invitation internes', () {
  expect(RetourAuth.destination('/join/JETON'), '/join/JETON');
  expect(RetourAuth.destination('/rejoindre/PLAN-K7M2X9'), '/rejoindre/PLAN-K7M2X9');
});

test('refuse une redirection externe ou privilégiée', () {
  for (final valeur in [
    'https://evil.test/join/JETON',
    '//evil.test/join/JETON',
    '/admin/comptes',
    '/join/JETON/participer',
    '/join/JETON#fragment',
  ]) {
    expect(RetourAuth.destination(valeur), PpRoutes.accueil, reason: valeur);
  }
});
```

- [x] **Step 2: Lancer et constater RED**

```bash
cd app && flutter test test/app/retour_auth_test.dart
```

Expected: échec de compilation, car `RetourAuth` n’existe pas.

- [x] **Step 3: Implémenter la liste positive**

Parser avec `Uri.tryParse`, refuser schéma, autorité, query et fragment, puis accepter exactement deux segments non vides : `join/{token}` ou `rejoindre/{code}`. Les constructeurs utilisent `Uri(path: route, queryParameters: {'retour': destination})` afin de laisser Dart encoder la valeur.

- [x] **Step 4: Brancher le routeur et les écrans auth**

Ajouter `String? retour` aux constructeurs de `ConnexionPage` et `InscriptionPage`. Les builders de route lisent `state.uri.queryParameters['retour']`. Après succès, naviguer vers `RetourAuth.destination(retour)`. Le lien connexion → inscription conserve le même retour. Quand une session connectée atteint une route auth publique, le redirect du routeur utilise lui aussi la destination validée.

- [x] **Step 5: Tester le parcours réel du routeur**

Ajouter des widget tests : `/connexion?retour=%2Fjoin%2FJETON` mène à l’aperçu après connexion ; le lien `Créer un compte` conserve le retour ; un retour externe mène à `/`. Utiliser le vrai routeur et doubler uniquement l’appel réseau d’authentification.

```bash
cd app && flutter test test/app/retour_auth_test.dart test/router_test.dart test/features/connexion_test.dart
```

Expected: tous les tests ciblés réussissent.

- [x] **Step 6: Committer le retour auth**

```bash
git commit --only app/lib/app/retour_auth.dart app/test/app/retour_auth_test.dart \
  app/lib/app/router.dart app/lib/features/auth/connexion_page.dart \
  app/lib/features/auth/inscription_page.dart app/test/features/connexion_test.dart \
  app/test/router_test.dart -m "feat(auth): revenir à l’invitation après connexion"
```

### Task 5: Remplacer le formulaire d’adhésion par l’entrée automatique

**Files:**
- Delete: `app/lib/features/rejoindre/adhesion_page.dart`
- Modify: `app/lib/features/rejoindre/apercu_invitation_page.dart`
- Modify: `app/lib/core/network/evenements_api.dart`
- Modify: `app/lib/core/network/api_client.dart`
- Modify: `app/lib/core/providers.dart`
- Modify: `app/lib/core/storage/session_store.dart`
- Modify: `app/lib/app/router.dart`
- Delete: `app/lib/features/evenement/sections/section_creer_un_compte.dart`
- Modify: `app/lib/features/evenement/tableau_de_bord_page.dart`
- Modify: `app/lib/l10n/arb/app_fr.arb`
- Modify: `app/test/features/adhesion_test.dart`
- Modify: `app/test/doubles/session_store_double.dart`
- Modify: `app/test/router_test.dart`
- Modify: `app/test/features/accueil_boucle_test.dart`

**Interfaces:**
- Consumes: `RetourAuth`, `EtatSession.connecte`, les POST sans corps de Task 2.
- Produces: `EvenementsApi.rejoindreParJeton({required String jeton})` et `rejoindreParCode({required String code})`, chacun retournant l’identifiant d’événement.

- [x] **Step 1: Écrire les widget tests rouges**

Dans `adhesion_test.dart`, remplacer le groupe « Adhésion sans compte » par :

```dart
testWidgets('un anonyme choisit connexion ou création de compte', (tester) async {
  await monterApercuAnonyme(tester);
  expect(find.text('Se connecter'), findsOneWidget);
  expect(find.text('Créer un compte'), findsOneWidget);
  expect(find.text('Comment tu t’appelles ?'), findsNothing);
  expect(find.text('Tu viens ?'), findsNothing);
});

testWidgets('un compte rejoint automatiquement puis ouvre la soirée', (tester) async {
  final api = EvenementsApiInvitationDouble(eventId: 'e1');
  await monterApercuConnecte(tester, api: api);
  await tester.pumpAndSettle();
  expect(api.jetons, ['JETON']);
  expect(routeCourante(), '/events/e1');
});
```

Le double enregistre le jeton ou le code reçu et renvoie un `eventId` littéral ; les assertions portent sur la navigation et l’appel public réel de l’écran, pas sur un widget mocké.

- [x] **Step 2: Lancer et constater RED**

```bash
cd app && flutter test test/features/adhesion_test.dart test/router_test.dart
```

Expected: l’aperçu propose encore `Participer` et ouvre encore `AdhesionPage`.

- [x] **Step 3: Adapter l’API Flutter**

Les deux méthodes de `EvenementsApi` ne prennent plus `prenom` ni `statut`. `_rejoindre` envoie `corps: null`, conserve la clé d’idempotence, ne lit plus `guestToken` et retourne uniquement `eventId`.

Retirer `EtatSession.invite`, `reprendreCommeInvite`, `reclamerParticipations` et les méthodes de jeton invité du `SessionStore` et de ses doubles. Conserver le stockage des jetons de compte inchangé.

Dans `ApiClient`, envoyer uniquement `lireJetonAcces()` dans l’en-tête Bearer. Supprimer
`SectionCreerUnCompte` et son insertion dans `TableauDeBordPage`, puisqu’aucun membre
actif n’entre désormais sans compte.

- [x] **Step 4: Implémenter l’état d’adhésion automatique**

Transformer `ApercuInvitationPage` en `ConsumerStatefulWidget` avec gardes `_adhesionLancee`, `_adhesionEnCours` et `_erreurAdhesion`. Une fois l’aperçu chargé :

- session anonyme → boutons vers `RetourAuth.versConnexion` et `versInscription` ;
- session connectée + arrivées ouvertes → planifier une seule fois `_rejoindre`, puis `context.go(PpRoutes.versEvenement(eventId))` ;
- erreur → message et bouton `Réessayer` qui réarme la garde ;
- arrivées fermées → aucun POST ;
- `dejaMembre` → appeler le POST idempotent afin d’obtenir l’`eventId`, sans modifier la présence.

Supprimer `AdhesionPage`, `adhesionParJeton`, `adhesionParCode`, `versAdhesion` et `versAdhesionParCode`.

- [x] **Step 5: Vérifier GREEN et les branches d’erreur**

Ajouter les tests : code court équivalent, arrivées fermées sans POST, erreur réseau avec retry unique, double reconstruction sans double POST, aucune saisie de nom/statut.

```bash
cd app && flutter test test/features/adhesion_test.dart test/router_test.dart \
  test/features/connexion_test.dart test/core/evenements_api_test.dart
```

Expected: tous les tests ciblés réussissent.

- [x] **Step 6: Committer le parcours Flutter**

```bash
git commit --only app/lib/features/rejoindre/adhesion_page.dart \
  app/lib/features/rejoindre/apercu_invitation_page.dart \
  app/lib/core/network/evenements_api.dart app/lib/core/network/api_client.dart \
  app/lib/core/providers.dart \
  app/lib/core/storage/session_store.dart app/lib/app/router.dart \
  app/lib/features/evenement/sections/section_creer_un_compte.dart \
  app/lib/features/evenement/tableau_de_bord_page.dart \
  app/lib/l10n/arb/app_fr.arb app/test/features/adhesion_test.dart \
  app/test/doubles/session_store_double.dart app/test/router_test.dart \
  app/test/features/accueil_boucle_test.dart \
  -m "feat(invitation): entrer automatiquement dans la soirée"
```

### Task 6: Aligner l’URL locale et vérifier le repli Web

**Files:**
- Modify: `Makefile`
- Modify: `api/src/PartyPlan.Api/appsettings.Development.json`
- Modify: `api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs`
- Modify: `app/nginx.conf`
- Create: `tools/verifier-liens-web.sh`

**Interfaces:**
- Consumes: `App:PublicBaseUrl`, `WEB_DEV_PORT = 5173`, nginx SPA fallback existant.
- Produces: liens locaux `http://localhost:5173/join/{token}` avec `make api`; recette exécutable des routes profondes Web.

- [x] **Step 1: Écrire le test API rouge de l’URL locale**

Dans le test d’invitation, vérifier littéralement :

```csharp
invitation.RootElement.GetProperty("joinUrl").GetString()
    .ShouldStartWith("http://localhost:5173/join/");
```

- [x] **Step 2: Lancer et constater RED**

```bash
dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj \
  --filter 'FullyQualifiedName~EvenementsTests.Le_lien'
```

Expected: la valeur actuelle commence par `http://localhost:8080`.

- [x] **Step 3: Aligner la configuration de développement**

Ajouter `App.PublicBaseUrl = http://localhost:5173` dans `appsettings.Development.json` et `App__PublicBaseUrl=http://localhost:$(WEB_DEV_PORT)` dans la cible `make api`. Ne pas modifier Compose, qui sert réellement le Web sur `8080` et surcharge déjà la valeur.

- [x] **Step 4: Écrire une recette Web comportementale**

Créer `tools/verifier-liens-web.sh` qui prend une base URL, requête `/`, `/join/JETON-RECETTE` et `/rejoindre/PLAN-K7M2X9`, exige HTTP 200 et vérifie que les trois réponses portent le même marqueur du shell Flutter. Le script échoue sur une 404 ; il ne se contente pas de chercher `try_files` dans la configuration.

Ajouter dans nginx des locations exactes `/.well-known/assetlinks.json` et `/.well-known/apple-app-site-association` avec `Content-Type: application/json`, `Cache-Control: no-cache` et les en-têtes de sécurité, sans casser le fallback existant.

- [x] **Step 5: Vérifier GREEN**

```bash
dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj \
  --filter 'FullyQualifiedName~EvenementsTests.Le_lien'
docker build -t partyplan-web-links app
container_id=$(docker run -d -p 18080:80 partyplan-web-links)
trap 'docker rm -f "$container_id" >/dev/null' EXIT
./tools/verifier-liens-web.sh http://localhost:18080
```

Expected: test API vert et trois routes Web servies par le même shell Flutter.

- [x] **Step 6: Committer la configuration Web**

```bash
git commit --only Makefile api/src/PartyPlan.Api/appsettings.Development.json \
  api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs app/nginx.conf \
  tools/verifier-liens-web.sh -m "fix(invitation): servir les liens sur le bon Web"
```

### Task 7: Configurer et vérifier Android App Links

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/web/.well-known/assetlinks.json`
- Create: `tools/verifier-app-links-android.sh`
- Modify: `docs/developpement.md`

**Interfaces:**
- Consumes: domaine `partyplan.maxencecoeur.fr`, package `fr.maxencecoeur.partyplan`, empreinte SHA-256 réelle du keystore debug `99:AB:98:70:F1:32:06:6A:2D:48:66:05:4F:F3:F1:C6:46:3C:3E:5E:67:CB:82:77:54:CF:AB:E8:48:0D:20:B4`.
- Produces: association `delegate_permission/common.handle_all_urls` pour `/join/`.

- [x] **Step 1: Écrire le vérificateur rouge**

Le script `tools/verifier-app-links-android.sh` doit : recalculer l’empreinte du keystore fourni, lire `assetlinks.json`, échouer si le package ou l’empreinte diffère, construire le manifeste debug, puis vérifier dans le manifeste fusionné un intent HTTPS `autoVerify` limité à l’hôte et au préfixe `/join/`.

- [x] **Step 2: Lancer et constater RED**

```bash
./tools/verifier-app-links-android.sh "$HOME/.android/debug.keystore"
```

Expected: échec parce que le filtre HTTPS et `assetlinks.json` n’existent pas.

- [x] **Step 3: Ajouter le filtre et l’association**

Dans l’activité principale :

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="partyplan.maxencecoeur.fr"
        android:pathPrefix="/join/" />
</intent-filter>
```

Créer `assetlinks.json` avec le package exact et l’empreinte debug recalculée par le script. Documenter que l’empreinte Play App Signing devra être ajoutée avant publication ; le script accepte plusieurs empreintes mais exige toujours celle du keystore testé.

- [x] **Step 4: Vérifier GREEN et, si un appareil est connecté, la remise réelle**

```bash
./tools/verifier-app-links-android.sh "$HOME/.android/debug.keystore"
cd app && flutter build apk --debug
adb devices
```

Si un appareil apparaît :

```bash
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -W -a android.intent.action.VIEW \
  -d 'https://partyplan.maxencecoeur.fr/join/JETON-RECETTE' \
  fr.maxencecoeur.partyplan
```

Expected: vérificateur et build verts ; sur appareil, l’activité PartyPlan reçoit `/join/JETON-RECETTE`.

- [x] **Step 5: Committer Android App Links**

```bash
git commit --only app/android/app/src/main/AndroidManifest.xml \
  app/web/.well-known/assetlinks.json tools/verifier-app-links-android.sh \
  docs/developpement.md -m "feat(invitation): ouvrir les liens dans Android"
```

### Task 8: Préparer iOS Universal Links avec l’identité Apple réelle

> **Task 8 reportée par l’utilisateur.** Aucun entitlement, fichier AASA ou
> vérificateur iOS n’est créé ou vérifié dans ce livrable Web + Android.

**Files:**
- Create: `app/ios/Runner/Runner.entitlements`
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`
- Create only when a real Apple Team ID is available: `app/web/.well-known/apple-app-site-association`
- Create: `tools/verifier-universal-links-ios.sh`
- Modify: `docs/developpement.md`

**Interfaces:**
- Consumes: bundle `fr.maxencecoeur.partyplan`, domaine `partyplan.maxencecoeur.fr`, Apple Team ID lu depuis une signature/configuration réelle.
- Produces: entitlement `applinks:partyplan.maxencecoeur.fr` et association limitée à `/join/*`.

- [ ] **Step 1: Écrire le vérificateur rouge**

Le script reçoit le Team ID en argument, refuse une chaîne vide ou non conforme à `[A-Z0-9]{10}`, vérifie l’entitlement, le `CODE_SIGN_ENTITLEMENTS` des trois configurations Runner et l’`appID` exact dans le fichier d’association.

- [ ] **Step 2: Lancer le test structurel et constater RED**

Avec le Team ID réel fourni par le compte Apple :

```bash
./tools/verifier-universal-links-ios.sh "$APPLE_TEAM_ID_PARTYPLAN"
```

Expected: échec parce que les entitlements et l’association n’existent pas encore. Si aucun Team ID réel n’est disponible, arrêter cette tâche ici, signaler ce seul prérequis externe et ne créer aucun `apple-app-site-association` fictif.

- [ ] **Step 3: Configurer Runner et l’association**

Créer `Runner.entitlements` avec `com.apple.developer.associated-domains = [applinks:partyplan.maxencecoeur.fr]`. Ajouter `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` aux configurations Debug, Profile et Release. Générer l’association avec l’`appID` composé du Team ID réel et de `fr.maxencecoeur.partyplan`, et les components limités à `/join/*`.

- [ ] **Step 4: Vérifier GREEN sur macOS/Xcode**

```bash
./tools/verifier-universal-links-ios.sh "$APPLE_TEAM_ID_PARTYPLAN"
cd app && flutter build ios --debug --no-codesign
```

Puis sur un appareil signé, ouvrir depuis Messages ou Notes une URL canonique. Expected: l’application reçoit la route ; un appareil sans application ouvre le Web.

- [ ] **Step 5: Committer iOS seulement avec des valeurs réelles**

```bash
git commit --only app/ios/Runner/Runner.entitlements \
  app/ios/Runner.xcodeproj/project.pbxproj \
  app/web/.well-known/apple-app-site-association \
  tools/verifier-universal-links-ios.sh docs/developpement.md \
  -m "feat(invitation): ouvrir les liens dans iOS"
```

### Task 9: Régénérer les contrats et vérifier le premier livrable

**Files:**
- Modify: `docs/api/openapi.json`
- Modify only if generated localization changes: `app/lib/l10n/generated/*`
- Modify: `docs/superpowers/plans/2026-08-21-invitations-comptes-liens-profonds.md`

**Interfaces:**
- Consumes: Tasks 1 à 8.
- Produces: OpenAPI et code généré cohérents, preuves de vérification complètes, cases du plan cochées.

- [x] **Step 1: Régénérer les artefacts**

```bash
make openapi
cd app && flutter gen-l10n
```

Vérifier dans OpenAPI que les POST join exigent une sécurité Bearer, n’ont plus `JoinBody` et que `JoinResult` ne contient que `eventId` et `memberId`.

- [x] **Step 2: Formater et vérifier les diffs**

```bash
dotnet format api/PartyPlan.slnx --no-restore
cd app && dart format lib test
cd ..
git diff --check
```

- [x] **Step 3: Exécuter toute la vérification locale**

```bash
make test-api
make test-app
cd app && flutter analyze
cd ..
make frontieres
```

Expected: zéro test en échec, zéro diagnostic Flutter, frontières de modules valides.

- [x] **Step 4: Recette du parcours réel**

Démarrer `make api` et `make web`, créer une soirée avec un compte A, ouvrir le lien dans une session privée, créer ou connecter un compte B, vérifier l’entrée directe dans la soirée et `Sans réponse`, puis rouvrir le lien et vérifier l’absence de doublon et l’absence de modification d’une présence déjà choisie.

Exécuter aussi :

```bash
./tools/verifier-liens-web.sh http://localhost:5173
./tools/verifier-app-links-android.sh "$HOME/.android/debug.keystore"
```

Exécuter le vérificateur iOS uniquement avec le Team ID Apple réel.

- [x] **Step 5: Committer les artefacts générés et le plan coché**

```bash
git commit --only docs/api/openapi.json app/lib/l10n/generated \
  docs/superpowers/plans/2026-08-21-invitations-comptes-liens-profonds.md \
  -m "chore(invitation): vérifier le parcours avec compte"
```

- [ ] **Step 6: Demander une revue de code**

> Revue Task 9 omise sur instruction explicite ; aucune case cochée pour cette étape.

Utiliser `superpowers:requesting-code-review`, corriger toute exigence manquante, puis relancer les commandes de Step 3 avant d’annoncer le livrable terminé.

## Follow-up Deliverables

Après validation du présent livrable :

1. écrire une spécification séparée pour SignalR et les mises à jour en direct ;
2. l’implémenter et le vérifier ;
3. écrire une spécification séparée Firebase Cloud Messaging ;
4. connecter `partyplan-99106` uniquement pour les notifications Web, Android et iOS.
