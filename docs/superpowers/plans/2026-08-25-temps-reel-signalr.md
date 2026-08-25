# Temps réel SignalR — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development`
> ou `superpowers:executing-plans` pour dérouler ce plan tâche par tâche. Les étapes sont
> des cases à cocher (`- [ ]`).

**But :** qu'un changement fait par une personne apparaisse chez les autres sans geste ni
rechargement, dans toute la soirée : présences, courses, dépenses, remboursements,
discussion, sondages.

**Architecture :** un hub SignalR unique, `/hubs/event`, un groupe par événement. Le hub
vit dans l'Infrastructure ; les modules ne le connaissent pas et diffusent par un contrat
public, `IDiffusionEvenement`, sur le modèle de `IPushSender` et `IAuditLog`. Le contrôle
d'appartenance à la connexion réutilise `IEventMembership`, qui existe déjà.

**Pile :** ASP.NET Core 10 (SignalR fourni par `Microsoft.AspNetCore.App`, aucune
dépendance serveur nouvelle), Flutter 3.38 avec `signalr_netcore ^1.4.4`.

**Spec :** `docs/cahier-des-charges.md` §9, règles `RG-RT-01` à `RG-RT-04`.

## Contraintes globales

Valeurs exactes, reprises du cahier des charges et de `CLAUDE.md`.

- `RG-RT-01` — hub exposé sur `/hubs/event`. Un groupe par événement, appartenance
  contrôlée **à l'établissement de la connexion**.
- `RG-RT-02` — chaque message porte l'état résultant de la ressource, pas seulement son
  identifiant. Le serveur envoie donc le DTO que REST renvoie déjà.
- `RG-RT-03` — le temps réel est une optimisation, **jamais la source de vérité**.
  L'interface doit rester exacte après une simple relecture REST, et une reconnexion
  déclenche un rechargement complet de l'écran actif.
- `RG-RT-04` — une seule instance d'API, donc aucun backplane. Ajouter une seconde
  instance impose Redis et un ADR préalable. **Ne pas introduire Redis dans ce lot.**
- `RG-SEC-01`, `RG-SEC-02` — un non-membre ne reçoit rien, et n'apprend pas que
  l'événement existe. Une connexion sur un événement dont l'appelant n'est pas membre est
  refusée sans distinguer « inexistant » de « interdit ».
- `NF-PERF-05` — propagation en moins d'une seconde.
- Règle 6 — un module n'accède pas aux tables d'un autre. La diffusion passe par un
  contrat du noyau partagé.
- Règle 5 — tout doit tourner en local. Le temps réel ne dépend d'aucun compte externe.
- Français dans l'interface et la documentation, anglais dans le code et les identifiants.

## Décision de conception à acter avant la tâche 1

Le cahier des charges §9 liste 18 messages. Deux écarts avec le produit réel :

- `schedule.changed` est **mort** : le planning est abandonné (feuille de route). Ne pas
  l'implémenter.
- La **discussion et les sondages ne sont pas couverts**. `activity.appended` ne suffit
  pas : un message de discussion n'est pas une ligne de fil d'activité. Quatre messages
  sont donc ajoutés : `message.created`, `message.deleted`, `poll.created`, `poll.voted`.

Le §9 du cahier des charges est corrigé en tâche 1, **avant** le code : un document qui
décrit un état faux est pire qu'absent.

Liste retenue, 21 messages :

```
member.joined         member.statusChanged   member.removed
item.created          item.updated           item.claimed
item.unclaimed        item.purchased         item.deleted
expense.created       expense.updated        expense.deleted
balances.changed      settlement.marked      settlement.cancelled
event.updated         activity.appended
message.created       message.deleted        poll.created
poll.voted
```

## Deuxième décision : le client invalide, il ne rapièce pas

`RG-RT-02` fait porter l'état par le message « afin d'éviter une requête de relecture ».
Ce lot **ne rapièce pas l'état local** : à la réception d'un message, le client invalide le
provider concerné et relit par REST.

Motif : rapiécer vingt et un messages dans autant de listes paginées, triées et filtrées
crée vingt et une occasions de désynchronisation silencieuse — un écran qui affiche autre
chose que la base, sans erreur. Invalider est impossible à désynchroniser par construction
et satisfait pleinement `RG-RT-03`. Le coût est une requête par message, pour des soirées
de moins de vingt personnes.

Le serveur envoie tout de même l'état résultant, ce qui honore `RG-RT-02` à la lettre et
laisse le rapiéçage possible plus tard sans toucher au serveur. Le report est consigné
dans la feuille de route.

## Structure des fichiers

**Serveur**

| Fichier | Responsabilité |
|---|---|
| `api/src/PartyPlan.SharedKernel/Contracts/IDiffusionEvenement.cs` | contrat de diffusion + noms des messages |
| `api/src/PartyPlan.Infrastructure/TempsReel/EventHub.cs` | le hub, et le contrôle d'appartenance à la connexion |
| `api/src/PartyPlan.Infrastructure/TempsReel/DiffusionSignalR.cs` | implémentation du contrat sur `IHubContext<EventHub>` |
| `api/src/PartyPlan.Infrastructure/DependencyInjection.cs` | enregistrement |
| `api/src/PartyPlan.Api/Program.cs` | `AddSignalR`, `MapHub` |

**Client**

| Fichier | Responsabilité |
|---|---|
| `app/lib/core/temps_reel/service_temps_reel.dart` | interface + implémentation `signalr_netcore` |
| `app/lib/core/temps_reel/message_temps_reel.dart` | le message reçu, typé |
| `app/lib/core/temps_reel/ecoute_evenement.dart` | traduit un message en invalidations |
| `app/lib/core/providers.dart` | providers |
| `app/lib/features/evenement/coquille_evenement.dart` | ouvre et ferme la connexion avec l'écran |

---

### Tâche 1 : corriger le cahier des charges

**Fichiers :**
- Modifier : `docs/cahier-des-charges.md` §9
- Modifier : `docs/roadmap.md` lot 1.6

Aucun code. Cette tâche existe parce que le §9 décrit aujourd'hui un produit qui n'est pas
celui qu'on construit, et que les tâches suivantes s'y réfèrent.

- [ ] **Étape 1 : remplacer la liste des messages**

Dans `docs/cahier-des-charges.md`, remplacer le bloc de 18 messages par les 21 ci-dessus,
puis ajouter sous la liste :

```markdown
`schedule.changed` a disparu avec le planning, abandonné. Les quatre messages
`message.*` et `poll.*` ont été ajoutés le 25/08/2026 : la discussion et les sondages
sont livrés depuis la V1.0, et `activity.appended` ne les couvrait pas — une ligne de fil
d'activité n'est pas un message de discussion.
```

- [ ] **Étape 2 : préciser RG-RT-02**

Ajouter à la suite de `RG-RT-02` :

```markdown
Le client de la V1 relit par REST à la réception d'un message plutôt que de rapiécer son
état local : rapiécer vingt et un messages dans autant de listes paginées et triées crée
autant d'occasions de désynchronisation silencieuse. L'état est tout de même envoyé, ce
qui laisse le rapiéçage possible sans toucher au serveur.
```

- [ ] **Étape 3 : commit**

```bash
git add docs/cahier-des-charges.md docs/roadmap.md
git commit -m "docs(temps-reel): acter les messages réellement diffusés"
```

---

### Tâche 2 : le contrat et le hub

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IDiffusionEvenement.cs`
- Créer : `api/src/PartyPlan.Infrastructure/TempsReel/EventHub.cs`
- Créer : `api/src/PartyPlan.Infrastructure/TempsReel/DiffusionSignalR.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`
- Modifier : `api/src/PartyPlan.Api/Program.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/TempsReelTests.cs`

**Interfaces :**
- Consomme : `IEventMembership.FindCurrentAsync`
- Produit : `IDiffusionEvenement.PublierAsync(Guid eventId, string message, object charge, CancellationToken)`,
  `MessagesTempsReel` (constantes), `EventHub`

- [ ] **Étape 1 : écrire le contrat**

`api/src/PartyPlan.SharedKernel/Contracts/IDiffusionEvenement.cs`

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Diffusion d'un changement aux membres connectés d'un événement (§9).
/// <para>
/// Contrat du noyau partagé et non d'un module : six modules diffusent, et aucun ne doit
/// connaître SignalR ni le hub. Même motif que <see cref="IPushSender"/> et
/// <see cref="IAuditLog"/>.
/// </para>
/// <para>
/// Aucune méthode ne lève : une diffusion perdue ne doit jamais faire échouer l'action
/// métier qui l'a déclenchée. Le temps réel est une optimisation (RG-RT-03), et le client
/// retrouve la vérité par une relecture REST.
/// </para>
/// </summary>
public interface IDiffusionEvenement
{
    /// <param name="eventId">Événement dont le groupe reçoit le message.</param>
    /// <param name="message">Un nom de <see cref="MessagesTempsReel"/>.</param>
    /// <param name="charge">
    /// État résultant de la ressource, pas son seul identifiant (RG-RT-02). En pratique
    /// le DTO que l'endpoint REST renvoie déjà.
    /// </param>
    Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken);
}

/// <summary>
/// Noms des messages diffusés (§9). Chaînes stables : un client déployé les compare
/// littéralement, en renommer une casse les applications déjà installées.
/// </summary>
public static class MessagesTempsReel
{
    public const string MembreArrive = "member.joined";
    public const string MembreStatutChange = "member.statusChanged";
    public const string MembreRetire = "member.removed";

    public const string ArticleCree = "item.created";
    public const string ArticleModifie = "item.updated";
    public const string ArticleAttribue = "item.claimed";
    public const string ArticleLibere = "item.unclaimed";
    public const string ArticleAchete = "item.purchased";
    public const string ArticleSupprime = "item.deleted";

    public const string DepenseCreee = "expense.created";
    public const string DepenseModifiee = "expense.updated";
    public const string DepenseSupprimee = "expense.deleted";

    public const string SoldesChanges = "balances.changed";
    public const string ReglementMarque = "settlement.marked";
    public const string ReglementAnnule = "settlement.cancelled";

    public const string EvenementModifie = "event.updated";
    public const string ActiviteAjoutee = "activity.appended";

    public const string MessageCree = "message.created";
    public const string MessageSupprime = "message.deleted";
    public const string SondageCree = "poll.created";
    public const string SondageVote = "poll.voted";
}
```

- [ ] **Étape 2 : écrire le test qui échoue**

`api/tests/PartyPlan.IntegrationTests/TempsReelTests.cs`

Le test porte sur ce qui compte et sur rien d'autre : le cloisonnement. Un non-membre ne
doit pas pouvoir s'abonner, et ne doit pas apprendre que l'événement existe.

```csharp
namespace PartyPlan.IntegrationTests;

using System.Net;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Cloisonnement du hub temps réel (RG-RT-01, RG-SEC-01, RG-SEC-02).
/// <para>
/// Ce sont les seuls tests d'intégration du temps réel : la mécanique de SignalR est
/// celle du framework, ce qui nous appartient est de refuser les non-membres. Un hub qui
/// laisserait passer diffuserait le contenu d'un événement privé à un inconnu.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class TempsReelTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Le_hub_est_expose_et_refuse_un_appelant_anonyme()
    {
        using var client = fixture.CreateClient();

        // La négociation SignalR est un POST : un GET est refusé par le framework, ce
        // qui ne nous apprendrait rien. C'est bien la négociation qu'on interroge.
        var reponse = await client.PostAsync(
            new Uri("/hubs/event/negotiate?negotiateVersion=1", UriKind.Relative),
            content: null);

        // 401 et non 404 : la route existe, c'est la session qui manque.
        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }
}
```

- [ ] **Étape 3 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj --filter "FullyQualifiedName~TempsReel"`
Attendu : ÉCHEC, 404 au lieu de 401 — le hub n'est pas monté.

- [ ] **Étape 4 : écrire le hub**

`api/src/PartyPlan.Infrastructure/TempsReel/EventHub.cs`

```csharp
namespace PartyPlan.Infrastructure.TempsReel;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Hub temps réel des événements — `RG-RT-01`, exposé sur <c>/hubs/event</c>.
/// <para>
/// Un groupe par événement, et l'appartenance est vérifiée **à l'établissement de la
/// connexion** plutôt qu'à chaque message : une vérification par message coûterait une
/// requête à chaque diffusion, et l'exclusion d'un membre ferme sa connexion.
/// </para>
/// <para>
/// L'identifiant de l'événement voyage en chaîne de requête et non en argument de
/// méthode : le client doit être dans le bon groupe avant le premier message, et une
/// méthode d'abonnement laisserait une fenêtre où il est connecté sans être filtré.
/// </para>
/// </summary>
[Authorize]
public sealed class EventHub(
    IEventMembership appartenance,
    ILogger<EventHub> logger) : Hub
{
    /// <summary>Nom du groupe. Un préfixe évite toute collision avec un autre usage.</summary>
    public static string Groupe(Guid eventId) => $"event:{eventId}";

    public override async Task OnConnectedAsync()
    {
        var brut = Context.GetHttpContext()?.Request.Query["eventId"].ToString();

        if (!Guid.TryParse(brut, out var eventId))
        {
            // Aucun événement demandé : rien à écouter, on refuse plutôt que de laisser
            // une connexion inutile ouverte.
            Context.Abort();
            return;
        }

        var membre = await appartenance
            .FindCurrentAsync(eventId, Context.ConnectionAborted)
            .ConfigureAwait(false);

        if (membre is null)
        {
            // Abandon sans message : distinguer « pas membre » de « inexistant »
            // révélerait l'existence de l'événement (RG-SEC-02).
            logger.LogInformation(
                "Connexion temps réel refusée : appelant non membre de {Evenement}.",
                eventId);
            Context.Abort();
            return;
        }

        await Groups
            .AddToGroupAsync(Context.ConnectionId, Groupe(eventId), Context.ConnectionAborted)
            .ConfigureAwait(false);

        await base.OnConnectedAsync().ConfigureAwait(false);
    }
}
```

- [ ] **Étape 5 : écrire l'implémentation de la diffusion**

`api/src/PartyPlan.Infrastructure/TempsReel/DiffusionSignalR.cs`

```csharp
namespace PartyPlan.Infrastructure.TempsReel;

using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Diffusion par SignalR. Seule implémentation de <see cref="IDiffusionEvenement"/>.
/// <para>
/// Le nom de la méthode invoquée chez le client est fixe, <c>Changement</c>, et le nom du
/// message voyage en argument. Une méthode par message obligerait le client à s'abonner
/// vingt et une fois et à évoluer à chaque ajout.
/// </para>
/// </summary>
public sealed class DiffusionSignalR(
    IHubContext<EventHub> hub,
    ILogger<DiffusionSignalR> logger) : IDiffusionEvenement
{
    public async Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken)
    {
        try
        {
            await hub.Clients
                .Group(EventHub.Groupe(eventId))
                .SendAsync("Changement", message, charge, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception erreur) when (erreur is not OperationCanceledException)
        {
            // Aucune exception ne franchit cette frontière : une diffusion perdue ne doit
            // pas faire échouer la dépense ou l'achat qui l'a déclenchée (RG-RT-03). Le
            // client retrouvera l'état exact à sa prochaine relecture.
            logger.LogWarning(
                erreur,
                "Diffusion {Message} perdue pour l'événement {Evenement}.",
                message,
                eventId);
        }
    }
}
```

- [ ] **Étape 6 : enregistrer et monter**

Dans `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`, à la suite des autres
contrats :

```csharp
        // Temps réel. Aucun backplane : une seule instance d'API (RG-RT-04).
        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IDiffusionEvenement,
            TempsReel.DiffusionSignalR>();
```

Dans `api/src/PartyPlan.Api/Program.cs`, avant la construction de l'application :

```csharp
builder.Services.AddSignalR();
```

et après `app.UseAuthentication();` — l'ordre importe, le hub porte `[Authorize]` :

```csharp
// Le hub vit hors du groupe /v1 : ce n'est pas une ressource REST versionnée, et
// RG-RT-01 fixe son adresse à /hubs/event.
app.MapHub<PartyPlan.Infrastructure.TempsReel.EventHub>("/hubs/event");
```

- [ ] **Étape 7 : lancer le test, vérifier qu'il passe**

Commande : `dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj --filter "FullyQualifiedName~TempsReel"`
Attendu : 1 test réussi.

- [ ] **Étape 8 : frontières et ensemble**

```bash
make frontieres
make verif
```
Attendu : 11 modules, aucune violation ; toute la suite verte.

- [ ] **Étape 9 : commit**

```bash
git add api docs
git commit -m "feat(temps-reel): hub SignalR et contrat de diffusion"
```

---

### Tâche 3 : les présences et l'événement diffusent

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/AttendanceService.cs`
- Modifier : `api/src/PartyPlan.Modules.Events/Application/EventService.cs`
- Test : `api/tests/PartyPlan.UnitTests/DiffusionPresencesTests.cs`

**Interfaces :**
- Consomme : `IDiffusionEvenement`, `MessagesTempsReel`
- Produit : rien de nouveau ; les services acquièrent une dépendance

- [ ] **Étape 1 : écrire le test qui échoue**

`api/tests/PartyPlan.UnitTests/DiffusionPresencesTests.cs`

Le test vérifie ce qui se diffuse, pas comment. Une doublure enregistre les publications.

```csharp
namespace PartyPlan.UnitTests;

using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Ce qu'un changement de présence diffuse (§9).
/// <para>
/// La charge est vérifiée non nulle et le nom du message exact : c'est ce couple que le
/// client déployé compare littéralement, et une faute de frappe y est invisible côté
/// serveur.
/// </para>
/// </summary>
public sealed class DiffusionPresencesTests
{
    [Fact]
    public void Les_noms_de_messages_sont_ceux_du_cahier_des_charges()
    {
        // Un test de constantes paraît futile jusqu'au jour où un renommage
        // « d'harmonisation » coupe le temps réel de toutes les applications installées.
        MessagesTempsReel.MembreArrive.ShouldBe("member.joined");
        MessagesTempsReel.MembreStatutChange.ShouldBe("member.statusChanged");
        MessagesTempsReel.MembreRetire.ShouldBe("member.removed");
        MessagesTempsReel.EvenementModifie.ShouldBe("event.updated");
    }
}

/// <summary>Doublure enregistrant les diffusions, réutilisée par les autres tests.</summary>
internal sealed class DiffusionDeTest : IDiffusionEvenement
{
    internal List<(Guid Evenement, string Message, object Charge)> Publications { get; } = [];

    public Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken)
    {
        Publications.Add((eventId, message, charge));
        return Task.CompletedTask;
    }
}
```

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~DiffusionPresences"`
Attendu : ÉCHEC de compilation si la tâche 2 n'est pas faite ; sinon PASSE — c'est un test
de garde, il n'a pas de phase rouge utile. Le rouge utile vient de l'étape 3.

- [ ] **Étape 3 : écrire le test d'intégration qui échoue**

Ajouter à `api/tests/PartyPlan.IntegrationTests/TempsReelTests.cs` :

```csharp
    [Fact]
    public async Task Un_changement_de_presence_est_diffuse()
    {
        // Le hub est difficile à observer en test d'intégration sans client SignalR.
        // Ce qui est vérifiable et suffisant : le service publie. La fixture substitue
        // IDiffusionEvenement par une doublure, exposée par la fixture.
        var diffusions = fixture.Diffusions;
        diffusions.Clear();

        using var client = await fixture.ClientMembreAsync();

        var reponse = await client.PutAsJsonAsync(
            new Uri($"/v1/events/{fixture.EvenementId}/attendance/me", UriKind.Relative),
            new { status = "Going" });

        reponse.EnsureSuccessStatusCode();

        diffusions.Select(d => d.Message)
            .ShouldContain(MessagesTempsReel.MembreStatutChange);
    }
```

Cette étape suppose que `PartyPlanApiFixture` expose `Diffusions`, `ClientMembreAsync()`
et `EvenementId`. Vérifier ce qu'elle offre déjà — `grep -n "public" api/tests/PartyPlan.IntegrationTests/Infrastructure/PartyPlanApiFixture.cs` —
et compléter la fixture avec une substitution de `IDiffusionEvenement` par
`DiffusionDeTest`. Si la fixture n'a pas d'événement de référence, en créer un dans le
test par les endpoints publics plutôt que d'en ajouter un à la fixture.

- [ ] **Étape 4 : lancer, vérifier l'échec**

Attendu : ÉCHEC, aucune publication enregistrée.

- [ ] **Étape 5 : diffuser depuis AttendanceService**

Ajouter `IDiffusionEvenement diffusion` au constructeur principal du service, puis après
chaque enregistrement réussi :

- dans `DeclarerAsync`, après `SaveChangesAsync` :

```csharp
        await diffusion
            .PublierAsync(eventId, MessagesTempsReel.MembreStatutChange, vue, cancellationToken)
            .ConfigureAwait(false);
```

où `vue` est le `MemberView` déjà construit pour la réponse — l'état résultant, pas
l'identifiant (`RG-RT-02`).

- dans `ExclureAsync`, avec `MessagesTempsReel.MembreRetire` et pour charge
  `new { memberId }` : le membre n'existe plus, il n'y a pas d'état à envoyer.
- dans `QuitterAsync`, idem.
- dans le service d'adhésion — celui qui traite `/join` — avec
  `MessagesTempsReel.MembreArrive` et le `MemberView` du nouveau membre. Le trouver par
  `grep -rn "rejoindre\|Join" api/src/PartyPlan.Modules.Events/Application/`.

Dans `EventService.ModifierAsync` (ou son nom réel, à vérifier), diffuser
`MessagesTempsReel.EvenementModifie` avec le `EventSummary` renvoyé.

- [ ] **Étape 6 : lancer, vérifier le vert**

Attendu : les tests de la tâche 3 passent.

- [ ] **Étape 7 : `make verif` puis commit**

```bash
make verif
git add api
git commit -m "feat(temps-reel): diffuser les présences et les modifications d'événement"
```

---

### Tâche 4 : les courses diffusent

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Shopping/Application/ShoppingService.cs`
- Test : ajouts à `api/tests/PartyPlan.IntegrationTests/TempsReelTests.cs`

**Interfaces :**
- Consomme : `IDiffusionEvenement`, `MessagesTempsReel`

- [ ] **Étape 1 : écrire le test qui échoue**

```csharp
    [Fact]
    public async Task Chaque_geste_sur_un_article_est_diffuse()
    {
        var diffusions = fixture.Diffusions;
        using var client = await fixture.ClientMembreAsync();
        var evenement = fixture.EvenementId;

        diffusions.Clear();
        var creation = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{evenement}/items", UriKind.Relative),
            new { name = "Bières", quantity = 24.0, unit = "bouteilles" });
        creation.EnsureSuccessStatusCode();

        diffusions.Select(d => d.Message).ShouldContain(MessagesTempsReel.ArticleCree);

        // La charge porte l'état, pas l'identifiant seul : sans quoi RG-RT-02 n'est pas
        // tenue et le rapiéçage futur serait impossible.
        diffusions.Last(d => d.Message == MessagesTempsReel.ArticleCree)
            .Charge.ShouldNotBeNull();
    }
```

- [ ] **Étape 2 : lancer, vérifier l'échec**

Attendu : ÉCHEC, aucune publication.

- [ ] **Étape 3 : diffuser depuis ShoppingService**

Ajouter `IDiffusionEvenement diffusion` au constructeur, puis une publication après chaque
mutation réussie, avec la vue déjà construite pour la réponse :

| Méthode | Message | Charge |
|---|---|---|
| `AjouterAsync` | `ArticleCree` | la `ShoppingItemView` renvoyée |
| `ModifierAsync` | `ArticleModifie` | la vue renvoyée |
| `AttribuerAsync` | `ArticleAttribue` | la vue renvoyée |
| `LibererAsync` | `ArticleLibere` | la vue renvoyée |
| `AcheterAsync` | `ArticleAchete` | la vue renvoyée |
| `SupprimerAsync` | `ArticleSupprime` | `new { itemId }` |

`AcheterAsync` crée aussi une dépense (voir `IExpenseFromPurchase`). Diffuser en plus
`MessagesTempsReel.DepenseCreee` et `MessagesTempsReel.SoldesChanges` **depuis le module
Expenses**, pas depuis Shopping : c'est lui qui possède la dépense, et Shopping ne doit
pas prétendre décrire l'état d'une ressource qui ne lui appartient pas (règle 6).

- [ ] **Étape 4 : lancer, vérifier le vert**

- [ ] **Étape 5 : `make verif` puis commit**

```bash
make verif
git add api
git commit -m "feat(temps-reel): diffuser les changements de liste de courses"
```

---

### Tâche 5 : les dépenses, les soldes et les remboursements diffusent

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Expenses/Application/` — le service de dépenses
- Modifier : `api/src/PartyPlan.Modules.Settlements/Application/` — le service de règlements
- Test : ajouts à `TempsReelTests.cs`

**Interfaces :**
- Consomme : `IDiffusionEvenement`, `MessagesTempsReel`

- [ ] **Étape 1 : écrire le test qui échoue**

```csharp
    [Fact]
    public async Task Une_depense_diffuse_aussi_les_soldes()
    {
        var diffusions = fixture.Diffusions;
        using var client = await fixture.ClientMembreAsync();

        diffusions.Clear();
        var reponse = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{fixture.EvenementId}/expenses", UriKind.Relative),
            new { label = "Courses", amount = 42.50m, paidByMemberId = fixture.MembreId });
        reponse.EnsureSuccessStatusCode();

        var messages = diffusions.Select(d => d.Message).ToList();

        messages.ShouldContain(MessagesTempsReel.DepenseCreee);
        // Une dépense change forcément les soldes : ne diffuser que la dépense
        // laisserait l'écran des remboursements faux jusqu'à sa prochaine ouverture.
        messages.ShouldContain(MessagesTempsReel.SoldesChanges);
    }
```

- [ ] **Étape 2 : lancer, vérifier l'échec**

- [ ] **Étape 3 : diffuser**

Dans le service de dépenses, après chaque mutation :

| Méthode | Messages |
|---|---|
| création | `DepenseCreee` puis `SoldesChanges` |
| modification | `DepenseModifiee` puis `SoldesChanges` |
| suppression | `DepenseSupprimee` puis `SoldesChanges` |

Charge de `SoldesChanges` : `new { eventId }`. Les soldes se recalculent, et envoyer un
tableau complet de soldes dans chaque message le rendrait volumineux sans que le client
l'utilise — il invalide.

Dans le service de règlements : `ReglementMarque` et `ReglementAnnule`, chacun suivi de
`SoldesChanges`.

- [ ] **Étape 4 : lancer, vérifier le vert**

- [ ] **Étape 5 : `make verif` puis commit**

```bash
make verif
git add api
git commit -m "feat(temps-reel): diffuser les dépenses, les soldes et les remboursements"
```

---

### Tâche 6 : la discussion, les sondages et le fil d'activité diffusent

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Messages/Application/`
- Modifier : `api/src/PartyPlan.Modules.Polls/Application/`
- Test : ajouts à `TempsReelTests.cs`

- [ ] **Étape 1 : écrire le test qui échoue**

```csharp
    [Fact]
    public async Task Un_message_de_discussion_est_diffuse()
    {
        var diffusions = fixture.Diffusions;
        using var client = await fixture.ClientMembreAsync();

        diffusions.Clear();
        var reponse = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{fixture.EvenementId}/messages", UriKind.Relative),
            new { body = "On apporte quoi ?" });
        reponse.EnsureSuccessStatusCode();

        diffusions.Select(d => d.Message).ShouldContain(MessagesTempsReel.MessageCree);
    }
```

- [ ] **Étape 2 : lancer, vérifier l'échec**

- [ ] **Étape 3 : diffuser**

| Service | Méthode | Message | Charge |
|---|---|---|---|
| Messages | envoi | `MessageCree` | la vue du message |
| Messages | suppression | `MessageSupprime` | `new { messageId }` |
| Polls | création | `SondageCree` | la vue du sondage |
| Polls | vote | `SondageVote` | la vue du sondage avec ses résultats |

`ActiviteAjoutee` : trouver qui écrit le fil d'activité — `grep -rn "activity" api/src --include=*.cs | grep -v obj` —
et diffuser depuis ce point unique. S'il n'existe pas encore (lot 1.10 non fait), **ne pas
l'implémenter** : cocher la ligne serait faux. Le noter dans la feuille de route.

- [ ] **Étape 4 : lancer, vérifier le vert**

- [ ] **Étape 5 : `make verif` puis commit**

```bash
make verif
git add api
git commit -m "feat(temps-reel): diffuser la discussion et les sondages"
```

---

### Tâche 7 : le client Flutter

**Fichiers :**
- Modifier : `app/pubspec.yaml`
- Créer : `app/lib/core/temps_reel/message_temps_reel.dart`
- Créer : `app/lib/core/temps_reel/service_temps_reel.dart`
- Test : `app/test/core/temps_reel_test.dart`

**Interfaces :**
- Produit : `MessageTempsReel(nom, charge)`, `ServiceTempsReel.connecter(eventId)`,
  `ServiceTempsReel.messages`, `ServiceTempsReel.deconnecter()`

- [ ] **Étape 1 : ajouter la dépendance**

Dans `app/pubspec.yaml`, section `dependencies` :

```yaml
  # Temps réel (§9). Client SignalR en Dart pur : la négociation, la reconnexion et le
  # protocole JSON de SignalR ne se réécrivent pas à la main.
  signalr_netcore: ^1.4.4
```

Puis `cd app && flutter pub get`. Si la résolution échoue avec Flutter 3.38, prendre la
dernière version compatible annoncée et **noter la version retenue dans le message de
commit**.

- [ ] **Étape 2 : écrire le message typé**

`app/lib/core/temps_reel/message_temps_reel.dart`

```dart
/// Un changement diffusé par le serveur (§9).
///
/// Le nom est comparé littéralement aux constantes du serveur : c'est un contrat de
/// chaînes, et le client déployé ne peut pas être mis à jour en même temps que l'API.
class MessageTempsReel {
  const MessageTempsReel({required this.nom, this.charge});

  final String nom;

  /// État résultant de la ressource. Inutilisé pour l'instant : le client invalide et
  /// relit par REST plutôt que de rapiécer son état local. Conservé parce que le
  /// serveur l'envoie déjà et que le rapiéçage viendra sans toucher au serveur.
  final Object? charge;

  /// Familles de messages, pour décider quoi invalider sans énumérer les vingt et un.
  bool get toucheMembres => nom.startsWith('member.');
  bool get toucheCourses => nom.startsWith('item.');
  bool get toucheDepenses => nom.startsWith('expense.');
  bool get toucheSoldes =>
      nom == 'balances.changed' || nom.startsWith('settlement.');
  bool get toucheDiscussion => nom.startsWith('message.');
  bool get toucheSondages => nom.startsWith('poll.');
  bool get toucheEvenement => nom == 'event.updated';
}
```

- [ ] **Étape 3 : écrire le test qui échoue**

`app/test/core/temps_reel_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/temps_reel/message_temps_reel.dart';

/// Le classement d'un message décide de ce qui est relu. Se tromper ici laisse un écran
/// faux sans qu'aucune erreur n'apparaisse.
void main() {
  group('MessageTempsReel', () {
    test('classe les messages par famille', () {
      expect(const MessageTempsReel(nom: 'member.joined').toucheMembres, isTrue);
      expect(const MessageTempsReel(nom: 'item.claimed').toucheCourses, isTrue);
      expect(
        const MessageTempsReel(nom: 'expense.created').toucheDepenses,
        isTrue,
      );
      expect(
        const MessageTempsReel(nom: 'balances.changed').toucheSoldes,
        isTrue,
      );
      // Un règlement change les soldes : le classer ailleurs laisserait l'écran des
      // remboursements périmé.
      expect(
        const MessageTempsReel(nom: 'settlement.marked').toucheSoldes,
        isTrue,
      );
      expect(
        const MessageTempsReel(nom: 'message.created').toucheDiscussion,
        isTrue,
      );
      expect(const MessageTempsReel(nom: 'poll.voted').toucheSondages, isTrue);
      expect(
        const MessageTempsReel(nom: 'event.updated').toucheEvenement,
        isTrue,
      );
    });

    test('un message inconnu ne touche rien', () {
      // Le serveur peut diffuser un message qu'une application ancienne ignore : elle
      // doit le laisser passer sans rien relire, et surtout sans lever.
      const inconnu = MessageTempsReel(nom: 'quelquechose.denouveau');

      expect(inconnu.toucheMembres, isFalse);
      expect(inconnu.toucheCourses, isFalse);
      expect(inconnu.toucheSoldes, isFalse);
    });
  });
}
```

- [ ] **Étape 4 : lancer, vérifier le rouge puis le vert**

Commande : `cd app && flutter test test/core/temps_reel_test.dart`
Le rouge vient de l'absence du fichier si l'étape 2 n'est pas encore faite ; sinon
constater le vert directement et le noter.

- [ ] **Étape 5 : écrire le service**

`app/lib/core/temps_reel/service_temps_reel.dart`

```dart
import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../storage/session_store.dart';
import 'message_temps_reel.dart';

/// Connexion temps réel à un événement (§9).
///
/// Une interface : les écrans se testent sans serveur, et le temps réel n'est jamais la
/// source de vérité (RG-RT-03) — une doublure inerte doit laisser l'application
/// parfaitement fonctionnelle.
abstract interface class ServiceTempsReel {
  /// Ouvre la connexion sur cet événement. Idempotente sur le même identifiant.
  Future<void> connecter(String evenementId);

  /// Ferme la connexion courante.
  Future<void> deconnecter();

  /// Messages reçus, et rien d'autre : les reconnexions sont signalées par
  /// [reconnexions] parce qu'elles imposent un rechargement complet et non une
  /// invalidation ciblée.
  Stream<MessageTempsReel> get messages;

  /// Émet à chaque reconnexion réussie. `RG-RT-03` : l'écran actif se recharge
  /// entièrement, ce qui a été manqué pendant la coupure étant inconnu.
  Stream<void> get reconnexions;
}

/// Implémentation SignalR.
///
/// Toute opération est sans effet si la connexion échoue : une soirée reste utilisable
/// sans temps réel, seulement moins vivante.
class ServiceTempsReelSignalR implements ServiceTempsReel {
  ServiceTempsReelSignalR({
    required String baseUrl,
    required SessionStore sessions,
  }) : _baseUrl = baseUrl,
       _sessions = sessions;

  final String _baseUrl;
  final SessionStore _sessions;

  final _messages = StreamController<MessageTempsReel>.broadcast();
  final _reconnexions = StreamController<void>.broadcast();

  HubConnection? _connexion;
  String? _evenementCourant;

  @override
  Stream<MessageTempsReel> get messages => _messages.stream;

  @override
  Stream<void> get reconnexions => _reconnexions.stream;

  @override
  Future<void> connecter(String evenementId) async {
    if (_evenementCourant == evenementId && _connexion != null) {
      return;
    }

    await deconnecter();

    // L'identifiant de l'événement est dans l'adresse : le hub doit pouvoir filtrer
    // avant le premier message, une méthode d'abonnement laisserait une fenêtre où la
    // connexion est établie sans être restreinte.
    final adresse = '$_baseUrl/hubs/event?eventId=$evenementId';

    final connexion = HubConnectionBuilder()
        .withUrl(
          adresse,
          options: HttpConnectionOptions(
            // Le jeton est relu à chaque tentative : il ne vit que quinze minutes, et
            // une reconnexion avec un jeton périmé échouerait indéfiniment.
            accessTokenFactory: () async =>
                await _sessions.jetonAcces() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    connexion.on('Changement', (arguments) {
      if (arguments == null || arguments.isEmpty) {
        return;
      }

      _messages.add(
        MessageTempsReel(
          nom: arguments.first as String,
          charge: arguments.length > 1 ? arguments[1] : null,
        ),
      );
    });

    connexion.onreconnected(({String? connectionId}) {
      _reconnexions.add(null);
    });

    try {
      await connexion.start();
      _connexion = connexion;
      _evenementCourant = evenementId;
    } catch (_) {
      // Pas de temps réel : l'application reste exacte, elle exige seulement une
      // actualisation manuelle. Ne rien lever ici, l'écran s'ouvrirait en erreur.
      _connexion = null;
      _evenementCourant = null;
    }
  }

  @override
  Future<void> deconnecter() async {
    final connexion = _connexion;
    _connexion = null;
    _evenementCourant = null;

    if (connexion == null) {
      return;
    }

    try {
      await connexion.stop();
    } catch (_) {
      // Rien à faire : la connexion est abandonnée de toute façon.
    }
  }
}
```

Vérifier la signature réelle de `SessionStore` pour la lecture du jeton :
`grep -n "jetonAcces\|Future<String?>" app/lib/core/storage/session_store.dart`, et
adapter l'appel.

- [ ] **Étape 6 : `make verif` puis commit**

```bash
make verif
git add app
git commit -m "feat(temps-reel): client SignalR et classement des messages"
```

---

### Tâche 8 : brancher les écrans

**Fichiers :**
- Créer : `app/lib/core/temps_reel/ecoute_evenement.dart`
- Modifier : `app/lib/core/providers.dart`
- Modifier : `app/lib/features/evenement/coquille_evenement.dart`
- Test : `app/test/features/temps_reel_ecran_test.dart`

**Interfaces :**
- Consomme : `ServiceTempsReel`, les providers d'événement
- Produit : `serviceTempsReelProvider`, `EcouteEvenement`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/features/temps_reel_ecran_test.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/temps_reel/message_temps_reel.dart';
import 'package:partyplan/core/temps_reel/service_temps_reel.dart';

/// Un message reçu doit provoquer une relecture, sinon le temps réel ne sert à rien.
void main() {
  test('un message de présence invalide les membres', () async {
    var relectures = 0;

    final membres = FutureProvider.family<int, String>((ref, id) async {
      relectures++;
      return relectures;
    });

    final service = _ServiceDouble();
    final conteneur = ProviderContainer(
      overrides: [serviceTempsReelProvider.overrideWithValue(service)],
    );
    addTearDown(conteneur.dispose);

    conteneur.listen(membres('e1'), (_, _) {});
    await conteneur.read(membres('e1').future);
    expect(relectures, 1);

    // L'écoute traduit un message en invalidations. Ici on la pilote directement.
    final ecoute = EcouteEvenement(
      evenementId: 'e1',
      invalider: () => conteneur.invalidate(membres('e1')),
    )..demarrer(service);

    service.emettre(const MessageTempsReel(nom: 'member.statusChanged'));
    await Future<void>.delayed(Duration.zero);
    await conteneur.read(membres('e1').future);

    expect(relectures, 2, reason: 'un message doit provoquer une relecture');

    await ecoute.arreter();
  });
}

class _ServiceDouble implements ServiceTempsReel {
  final _messages = StreamController<MessageTempsReel>.broadcast();
  final _reconnexions = StreamController<void>.broadcast();

  void emettre(MessageTempsReel m) => _messages.add(m);

  @override
  Stream<MessageTempsReel> get messages => _messages.stream;

  @override
  Stream<void> get reconnexions => _reconnexions.stream;

  @override
  Future<void> connecter(String evenementId) async {}

  @override
  Future<void> deconnecter() async {}
}
```

- [ ] **Étape 2 : lancer, vérifier l'échec**

Attendu : `EcouteEvenement` et `serviceTempsReelProvider` introuvables.

- [ ] **Étape 3 : écrire l'écoute**

`app/lib/core/temps_reel/ecoute_evenement.dart`

```dart
import 'dart:async';

import 'message_temps_reel.dart';
import 'service_temps_reel.dart';

/// Traduit un message diffusé en relectures.
///
/// Le client relit par REST plutôt que de rapiécer son état local : rapiécer vingt et un
/// messages dans autant de listes paginées et triées créerait autant d'occasions
/// d'afficher autre chose que la base, sans erreur visible. `RG-RT-03` fait de REST la
/// source de vérité, et invalider est impossible à désynchroniser.
class EcouteEvenement {
  EcouteEvenement({
    required this.evenementId,
    required this.invalider,
  });

  final String evenementId;

  /// Relit ce que l'écran affiche. Passée en fonction pour que l'écoute reste testable
  /// sans conteneur de providers.
  final void Function() invalider;

  StreamSubscription<MessageTempsReel>? _messages;
  StreamSubscription<void>? _reconnexions;

  void demarrer(ServiceTempsReel service) {
    _messages = service.messages.listen((_) => invalider());

    // Une reconnexion impose un rechargement complet : ce qui a été manqué pendant la
    // coupure est par définition inconnu (RG-RT-03).
    _reconnexions = service.reconnexions.listen((_) => invalider());
  }

  Future<void> arreter() async {
    await _messages?.cancel();
    await _reconnexions?.cancel();
  }
}
```

Noter que l'écoute invalide **tout** l'écran à chaque message, sans se servir du
classement par famille de la tâche 7. C'est volontaire pour cette étape : une soirée de
vingt personnes produit peu de messages, et un seul chemin est plus sûr que sept. Le
classement sert à affiner ensuite, et il est déjà testé.

- [ ] **Étape 4 : ajouter le provider**

Dans `app/lib/core/providers.dart` :

```dart
// ---------------------------------------------------------------- temps réel ----

final serviceTempsReelProvider = Provider<ServiceTempsReel>(
  (ref) => ServiceTempsReelSignalR(
    baseUrl: adresseApi,
    sessions: ref.watch(sessionStoreProvider),
  ),
);
```

Reprendre le nom réel de la constante d'adresse de l'API :
`grep -n "API_BASE_URL" app/lib/core/providers.dart app/lib/core/network/api_client.dart`.

- [ ] **Étape 5 : brancher la coquille d'événement**

Dans `app/lib/features/evenement/coquille_evenement.dart`, `initState` invalide déjà à
l'ouverture. Y ajouter la connexion, et la fermer dans `dispose` :

```dart
    final service = ref.read(serviceTempsReelProvider);
    // ignore: discarded_futures
    service.connecter(widget.eventId);

    _ecoute = EcouteEvenement(
      evenementId: widget.eventId,
      invalider: _relire,
    )..demarrer(service);
```

et dans `dispose` :

```dart
    // ignore: discarded_futures
    _ecoute?.arreter();
    // ignore: discarded_futures
    ref.read(serviceTempsReelProvider).deconnecter();
```

- [ ] **Étape 6 : lancer, vérifier le vert**

- [ ] **Étape 7 : `make verif` puis commit**

```bash
make verif
git add app
git commit -m "feat(temps-reel): relire l'écran d'événement à chaque changement diffusé"
```

---

### Tâche 9 : configuration, documentation, feuille de route

**Fichiers :**
- Modifier : `infra/compose/compose.nas.yml` — commentaire sur les Websockets
- Modifier : `docs/exploitation.md`
- Modifier : `docs/roadmap.md`

- [ ] **Étape 1 : documenter l'exigence de proxy**

Dans `docs/exploitation.md`, ajouter à la section de mise en service :

```markdown
### Websockets

Le hub temps réel vit sur `/hubs/event` du domaine de l'API. Le reverse proxy doit
autoriser la montée en Websocket sur ce domaine — case « Websockets Support » dans Nginx
Proxy Manager. Sans elle, SignalR bascule silencieusement en interrogation longue : le
temps réel fonctionne, plus lentement et en consommant davantage. Aucune erreur
n'apparaît, ce qui rend l'oubli difficile à repérer.
```

- [ ] **Étape 2 : cocher le lot 1.6**

Dans `docs/roadmap.md`, lot 1.6, cocher ce qui est fait et laisser explicitement ouvert :

- le rapiéçage de l'état local, reporté ;
- `activity.appended` si le fil d'activité n'existe pas encore (lot 1.10) ;
- la recette de propagation en moins d'une seconde (`NF-PERF-05`), qui demande deux
  appareils réels.

- [ ] **Étape 3 : `make verif` puis commit**

```bash
make verif
git add docs infra
git commit -m "docs(temps-reel): documenter l'exigence Websocket et l'état du lot"
```

---

## Vérification finale, à deux appareils

Aucun test automatisé ne remplace celle-ci.

- [ ] Ouvrir la même soirée sur un téléphone et dans un navigateur, avec deux comptes
      différents
- [ ] Déclarer une présence sur l'un : elle apparaît sur l'autre sans geste
- [ ] Ajouter un article, l'attribuer, l'acheter : les trois se propagent
- [ ] Ajouter une dépense : l'écran des remboursements de l'autre appareil change
- [ ] Envoyer un message de discussion : il apparaît sans actualiser
- [ ] Couper le réseau d'un appareil, faire trois changements sur l'autre, rétablir :
      l'appareil coupé doit se retrouver **exactement** à jour, pas partiellement
- [ ] Ouvrir la soirée avec un compte **non membre** : la connexion doit être refusée, et
      aucun message ne doit arriver
- [ ] Vérifier au journal de l'API qu'une connexion refusée est bien tracée
