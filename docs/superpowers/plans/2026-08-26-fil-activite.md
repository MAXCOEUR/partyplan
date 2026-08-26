# Fil d'activité — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUISE — `superpowers:subagent-driven-development`
> (recommandée) ou `superpowers:executing-plans` pour dérouler ce plan tâche par tâche.
> Les étapes sont des cases à cocher (`- [ ]`).

**But** : chaque action structurante d'un événement laisse une ligne horodatée et
inaltérable, lisible dans l'application, et le lot 1.6 se ferme.

**Architecture** : un contrat de noyau partagé `IJournalActivite` inscrit l'entrée dans
la **transaction** de l'action métier — c'est le `SaveChangesAsync` du service appelant
qui la valide. La diffusion `activity.appended` part **après** validation, comme les
autres messages temps réel. L'application compose la phrase affichée depuis `kind` +
payload ; la base ne stocke jamais de prose.

**Pile** : ASP.NET Core 10, EF Core 10, PostgreSQL, SignalR, Flutter 3.38, Riverpod,
xUnit, `flutter_test`.

**Spec** : `docs/superpowers/specs/2026-08-26-fil-activite-design.md` — à lire avant la
première tâche. Le plan argumente depuis elle.

## Contraintes globales

- **TDD sans exception** : test écrit, exécuté rouge, puis implémentation. Le `CLAUDE.md`
  en fait un point non négociable.
- **Cloisonnement** : toute requête remonte `User → EventMember → Event`. Un non-membre
  reçoit **404**, un `PlatformAdmin` non membre aussi (règle 2, `RG-ADM-01`).
- **Ajout seul** : ni `UPDATE` ni `DELETE` sur `activity_entries` (`NF-SEC-08`, règle 4).
- **Frontières de modules** : `Shopping`, `Expenses` et `Settlements` n'accèdent jamais
  aux tables de `Events`. Communication par contrat public uniquement (règle 6).
- **Montants** : `decimal` en C#, `numeric(10,2)` en base, jamais de `double` côté API.
- **Langue** : français dans l'interface et la documentation, anglais dans le code et les
  identifiants de base. **Exception assumée** : les clés de payload `jsonb` sont en
  français, la ligne déjà écrite en base portant `{"de": …, "vers": …}`.
- **Aucune chaîne en dur** dans un écran Flutter (`NF-I18N-01`) : tout passe par
  `app/lib/l10n/arb/app_fr.arb`.
- **Aucune couleur, marge, rayon ou taille en dur** : jetons de design uniquement.
- `make verif` doit passer avant tout push.
- Commits conventionnels avec périmètre : `feat(fil):`, `fix(fil):`, `docs(fil):`.
- **Cocher `docs/roadmap.md` au moment du commit**, jamais à la fin du lot.

---

## Tâche 1 : Amender le cahier des charges et les catégories

Le cahier des charges passe avant la feuille de route : c'est la règle du dépôt. Cette
tâche ne touche aucun comportement, elle rend les suivantes légitimes.

**Fichiers :**
- Modifier : `docs/cahier-des-charges.md:630-632` (`RG-FIL-01`)
- Modifier : `api/src/PartyPlan.Modules.Events/Domain/ActivityEntry.cs`
- Test : `api/tests/PartyPlan.UnitTests/ActivityKindsTests.cs` (créer)

**Interfaces :**
- Produit : `ActivityKinds` avec **13 constantes**, et `ActivityKinds.All` (nouveau),
  `IReadOnlyList<string>`, consommé par les tests des tâches 4 à 6.

- [ ] **Étape 1 : Réécrire `RG-FIL-01`**

Remplacer le texte actuel par :

```markdown
**RG-FIL-01** — Le fil d'activité enregistre au minimum : arrivée d'un membre,
changement de statut, ajout ou suppression d'article, attribution et libération,
achat, création, modification et suppression de dépense, marquage et annulation de
remboursement, modification de la date ou du lieu.

Les actions d'annulation sont consignées au même titre que les actions qu'elles
défont. Un fil qui enregistre l'attribution d'un article mais pas sa libération, ou le
marquage d'un remboursement mais pas son annulation, est trompeur là où il prétend
faire preuve — et c'est exactement la situation où deux membres se contredisent.
```

- [ ] **Étape 2 : Écrire le test des catégories**

Créer `api/tests/PartyPlan.UnitTests/ActivityKindsTests.cs` :

```csharp
namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Domain;

public sealed class ActivityKindsTests
{
    [Fact]
    public void All_couvre_les_treize_categories_de_RG_FIL_01()
    {
        Assert.Equal(13, ActivityKinds.All.Count);
    }

    [Fact]
    public void All_ne_contient_aucun_doublon()
    {
        Assert.Equal(ActivityKinds.All.Count, ActivityKinds.All.Distinct().Count());
    }

    [Fact]
    public void Le_planning_abandonne_ne_laisse_aucune_categorie()
    {
        // Le lot 1.9 a été abandonné le 21/08/2026. Une catégorie annonçant une
        // fonctionnalité inexistante se relit comme un oubli d'implémentation.
        Assert.DoesNotContain("event.schedule_changed", ActivityKinds.All);
    }
}
```

- [ ] **Étape 3 : Lancer le test, vérifier qu'il échoue**

```bash
cd api && dotnet test tests/PartyPlan.UnitTests --filter ActivityKindsTests
```

Attendu : ÉCHEC — `ActivityKinds.All` n'existe pas (erreur de compilation `CS0117`).

- [ ] **Étape 4 : Modifier `ActivityKinds`**

Dans `ActivityEntry.cs`, retirer `EventScheduleChanged`, ajouter les trois catégories
d'annulation et la liste :

```csharp
/// <summary>
/// Catégories du fil d'activité. Les treize catégories exigées par RG-FIL-01 sont
/// couvertes ; ne jamais renommer une valeur déjà écrite en base.
/// </summary>
public static class ActivityKinds
{
    public const string MemberJoined = "member.joined";
    public const string MemberStatusChanged = "member.status_changed";
    public const string ItemCreated = "item.created";
    public const string ItemDeleted = "item.deleted";
    public const string ItemClaimed = "item.claimed";
    public const string ItemUnclaimed = "item.unclaimed";
    public const string ItemPurchased = "item.purchased";
    public const string ExpenseCreated = "expense.created";
    public const string ExpenseUpdated = "expense.updated";
    public const string ExpenseDeleted = "expense.deleted";
    public const string SettlementMarked = "settlement.marked";
    public const string SettlementCancelled = "settlement.cancelled";
    public const string EventDateOrPlaceChanged = "event.date_or_place_changed";

    /// <summary>
    /// Toutes les catégories. Sert aux tests de couverture et à l'application, qui doit
    /// savoir composer une phrase pour chacune.
    /// </summary>
    public static readonly IReadOnlyList<string> All =
    [
        MemberJoined,
        MemberStatusChanged,
        ItemCreated,
        ItemDeleted,
        ItemClaimed,
        ItemUnclaimed,
        ItemPurchased,
        ExpenseCreated,
        ExpenseUpdated,
        ExpenseDeleted,
        SettlementMarked,
        SettlementCancelled,
        EventDateOrPlaceChanged,
    ];
}
```

- [ ] **Étape 5 : Lancer le test, vérifier qu'il passe**

```bash
cd api && dotnet test tests/PartyPlan.UnitTests --filter ActivityKindsTests
```

Attendu : 3 tests PASS.

- [ ] **Étape 6 : Commit**

```bash
git add docs/cahier-des-charges.md api/src/PartyPlan.Modules.Events/Domain/ActivityEntry.cs api/tests/PartyPlan.UnitTests/ActivityKindsTests.cs
git commit -m "feat(fil)!: RG-FIL-01 couvre les annulations, et le planning quitte les catégories

Un fil qui consigne l'attribution mais pas la libération, le marquage d'un
remboursement mais pas son annulation, trompe là où il prétend faire preuve.

event.schedule_changed est mort avec le planning abandonné le 21/08/2026 et
n'a jamais été écrit : le retirer ne réécrit aucune histoire."
```

---

## Tâche 2 : Le contrat `IJournalActivite`

Le cœur du lot. Tout le reste en dépend.

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IJournalActivite.cs`
- Créer : `api/src/PartyPlan.Infrastructure/Journal/JournalActivite.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/DependencyInjection.cs` (près de la ligne
  71, où `IDiffusionEvenement` est enregistré)
- Test : `api/tests/PartyPlan.IntegrationTests/JournalActiviteTests.cs` (créer)

**Interfaces :**
- Produit : `IJournalActivite.Consigner(Guid eventId, Guid? memberId, string actorName,
  string kind, object? donnees = null)` — **retourne `void`**, n'appelle jamais
  `SaveChangesAsync`. Consommé par les tâches 3 à 6.

- [ ] **Étape 1 : Écrire les tests**

Créer `api/tests/PartyPlan.IntegrationTests/JournalActiviteTests.cs`. Suivre la
convention d'amorçage des tests d'intégration existants — lire d'abord
`api/tests/PartyPlan.IntegrationTests/EventScopeIsolationTests.cs` pour la mise en place
Testcontainers et la création d'un événement avec un membre.

```csharp
namespace PartyPlan.IntegrationTests;

using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Contracts;

public sealed class JournalActiviteTests(BaseDeDonneesFixture fixture)
    : IClassFixture<BaseDeDonneesFixture>
{
    [Fact]
    public async Task Consigner_puis_SaveChanges_ecrit_la_ligne()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, membreId) = await essai.CreerEvenementAvecMembreAsync();

        var journal = essai.Service<IJournalActivite>();
        journal.Consigner(
            evenementId,
            membreId,
            "Camille",
            ActivityKinds.ItemCreated,
            new { libelle = "Glaçons" });

        await essai.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        var ligne = Assert.Single(
            await essai.LireActivitesAsync(evenementId));
        Assert.Equal(ActivityKinds.ItemCreated, ligne.Kind);
        Assert.Equal("Camille", ligne.ActorName);
        Assert.Equal(membreId, ligne.MemberId);
        Assert.Contains("Glaçons", ligne.Payload);
    }

    [Fact]
    public async Task Consigner_sans_SaveChanges_n_ecrit_rien()
    {
        // Le test qui compte. Si un jour Consigner sauvegardait lui-même, la garantie
        // de transaction tomberait sans qu'aucun autre test ne rougisse.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, membreId) = await essai.CreerEvenementAvecMembreAsync();

        essai.Service<IJournalActivite>().Consigner(
            evenementId,
            membreId,
            "Camille",
            ActivityKinds.ItemCreated);

        Assert.Empty(await essai.LireActivitesAsync(evenementId));
    }

    [Fact]
    public async Task Une_transaction_annulee_ne_laisse_aucune_ligne()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, membreId) = await essai.CreerEvenementAvecMembreAsync();

        await using (var transaction = await essai.Db.Database.BeginTransactionAsync(
            TestContext.Current.CancellationToken))
        {
            essai.Service<IJournalActivite>().Consigner(
                evenementId,
                membreId,
                "Camille",
                ActivityKinds.ExpenseCreated,
                new { libelle = "Courses", montant = 62.40m });

            await essai.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
            await transaction.RollbackAsync(TestContext.Current.CancellationToken);
        }

        Assert.Empty(await essai.LireActivitesAsync(evenementId));
    }

    [Fact]
    public async Task Le_payload_est_nul_quand_aucune_donnee_n_est_fournie()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, membreId) = await essai.CreerEvenementAvecMembreAsync();

        essai.Service<IJournalActivite>().Consigner(
            evenementId,
            membreId,
            "Camille",
            ActivityKinds.MemberJoined);
        await essai.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        Assert.Null(Assert.Single(await essai.LireActivitesAsync(evenementId)).Payload);
    }

    [Fact]
    public async Task Une_ligne_ecrite_ne_peut_etre_ni_modifiee_ni_supprimee()
    {
        // NF-SEC-08, règle 4. Le déclencheur couvre UPDATE, DELETE et TRUNCATE.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, membreId) = await essai.CreerEvenementAvecMembreAsync();

        essai.Service<IJournalActivite>().Consigner(
            evenementId, membreId, "Camille", ActivityKinds.MemberJoined);
        await essai.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        await Assert.ThrowsAnyAsync<Exception>(() => essai.Db.Database.ExecuteSqlRawAsync(
            "UPDATE activity_entries SET actor_name = 'Autre'",
            TestContext.Current.CancellationToken));

        await Assert.ThrowsAnyAsync<Exception>(() => essai.Db.Database.ExecuteSqlRawAsync(
            "DELETE FROM activity_entries",
            TestContext.Current.CancellationToken));
    }
}
```

Si les aides `NouvelEssaiAsync`, `CreerEvenementAvecMembreAsync`, `Service<T>()`, `Db` ou
`LireActivitesAsync` n'existent pas sous ces noms dans la fixture d'intégration, **suivre
les noms réels du dépôt** plutôt que de les créer en double, et n'ajouter que
`LireActivitesAsync` si elle manque.

- [ ] **Étape 2 : Lancer les tests, vérifier qu'ils échouent**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter JournalActiviteTests
```

Attendu : ÉCHEC de compilation — `IJournalActivite` n'existe pas.

- [ ] **Étape 3 : Écrire le contrat**

Créer `api/src/PartyPlan.SharedKernel/Contracts/IJournalActivite.cs` :

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Inscription d'une ligne au fil d'activité d'un événement (EF-FIL-01).
/// <para>
/// Contrat du noyau partagé et non du module Events : quatre modules journalisent, et
/// aucun ne doit accéder à <c>activity_entries</c> (règle 6). Même motif que
/// <see cref="IDiffusionEvenement"/> et <see cref="IAuditLog"/>.
/// </para>
/// <para>
/// <b>Garantie opposée à celle de la diffusion.</b> <see cref="IDiffusionEvenement"/>
/// part après validation et absorbe ses pannes : le temps réel est une optimisation.
/// Le fil, lui, est la trace de référence en cas de litige sur les montants
/// (RG-FIL-02) : il doit vivre ou mourir avec l'action qui l'a produit.
/// </para>
/// </summary>
public interface IJournalActivite
{
    /// <summary>
    /// Inscrit l'entrée au suivi de modifications, <b>sans sauvegarder</b>. C'est le
    /// <c>SaveChangesAsync</c> de l'appelant qui la valide, dans la même transaction que
    /// l'action métier.
    /// <para>
    /// Synchrone et sans <c>Task</c> à dessein : une signature asynchrone laisserait
    /// croire qu'un aller-retour en base a lieu ici, et inviterait à sauvegarder.
    /// </para>
    /// </summary>
    /// <param name="eventId">Événement auquel la ligne appartient.</param>
    /// <param name="memberId">Auteur. Nul pour une action système.</param>
    /// <param name="actorName">
    /// Nom de l'auteur à cet instant. Figé volontairement : un changement de nom
    /// ultérieur ne réécrit pas l'histoire (RG-USR-04).
    /// </param>
    /// <param name="kind">Une constante de <c>ActivityKinds</c>.</param>
    /// <param name="donnees">
    /// Contexte sérialisé en JSON — libellé, montant, ancienne et nouvelle valeur.
    /// <b>Jamais une phrase</b> : la ligne est inaltérable, une formulation stockée le
    /// serait aussi, et le fil ne serait jamais traduisible (NF-I18N-01).
    /// </param>
    void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null);
}
```

- [ ] **Étape 4 : Écrire l'implémentation**

Créer `api/src/PartyPlan.Infrastructure/Journal/JournalActivite.cs` :

```csharp
namespace PartyPlan.Infrastructure.Journal;

using System.Text.Json;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Seule implémentation de <see cref="IJournalActivite"/>. Écrit dans le contexte
/// unique, donc dans l'unité de travail en cours.
/// </summary>
public sealed class JournalActivite(
    PartyPlanDbContext db,
    IClock clock,
    IIdGenerator ids) : IJournalActivite
{
    /// <summary>
    /// Sérialisation sans échappement agressif : les libellés d'articles sont français et
    /// « Glaçons » stocké en ç serait illisible en base, où l'on relit ce fil en cas
    /// de litige.
    /// </summary>
    private static readonly JsonSerializerOptions Options = new()
    {
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder
            .UnsafeRelaxedJsonEscaping,
    };

    public void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null)
    {
        db.ActivityEntries.Add(new ActivityEntry
        {
            Id = ids.NewId(),
            EventId = eventId,
            MemberId = memberId,
            ActorName = actorName,
            Kind = kind,
            Payload = donnees is null ? null : JsonSerializer.Serialize(donnees, Options),
            CreatedAt = clock.UtcNow,
        });
    }
}
```

- [ ] **Étape 5 : Enregistrer le service**

Dans `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`, à côté de
l'enregistrement de `IDiffusionEvenement` (ligne 71 environ) :

```csharp
// Portée requête et non singleton, à l'inverse de la diffusion : l'implémentation
// écrit dans le DbContext de la requête en cours.
services.AddScoped<PartyPlan.SharedKernel.Contracts.IJournalActivite,
    PartyPlan.Infrastructure.Journal.JournalActivite>();
```

- [ ] **Étape 6 : Lancer les tests, vérifier qu'ils passent**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter JournalActiviteTests
```

Attendu : 5 tests PASS.

- [ ] **Étape 7 : Vérifier les frontières de modules**

```bash
./tools/verifier-frontieres-modules.sh
```

Attendu : sortie verte. Le contrat vit dans `SharedKernel`, l'implémentation dans
`Infrastructure` : aucun module ne référence un autre.

- [ ] **Étape 8 : Commit**

```bash
git add api/src/PartyPlan.SharedKernel/Contracts/IJournalActivite.cs api/src/PartyPlan.Infrastructure/Journal/JournalActivite.cs api/src/PartyPlan.Infrastructure/DependencyInjection.cs api/tests/PartyPlan.IntegrationTests/JournalActiviteTests.cs
git commit -m "feat(fil): contrat IJournalActivite, inscrit dans la transaction

Consigner n'appelle jamais SaveChangesAsync : l'entrée et l'action métier
partagent une transaction, donc une dépense enregistrée sans sa ligne de fil
est structurellement impossible.

Garantie opposée à celle de la diffusion, qui part après validation et absorbe
ses pannes. Le temps réel est une optimisation, le fil est une preuve."
```

---

## Tâche 3 : Basculer les trois écritures existantes

Faire passer du code qui marche déjà par le nouveau contrat éprouve le contrat sur un
comportement connu, avant de lui confier neuf écritures neuves.

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/JoinService.cs:157-165`
- Modifier : `api/src/PartyPlan.Modules.Events/Application/AttendanceService.cs:141-150`
- Modifier : `api/src/PartyPlan.Modules.Events/Application/EventService.cs:304-312`
- Test : `api/tests/PartyPlan.IntegrationTests/FilActiviteEventsTests.cs` (créer)

**Interfaces :**
- Consomme : `IJournalActivite.Consigner` (tâche 2).
- Produit : le payload `{"champs": ["date", "lieu"]}` sur `event.date_or_place_changed`,
  consommé par la composition de phrase de la tâche 10.

- [ ] **Étape 1 : Écrire le test**

```csharp
namespace PartyPlan.IntegrationTests;

using PartyPlan.Modules.Events.Domain;

public sealed class FilActiviteEventsTests(BaseDeDonneesFixture fixture)
    : IClassFixture<BaseDeDonneesFixture>
{
    [Fact]
    public async Task Rejoindre_consigne_l_arrivee_du_membre()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var evenementId = await essai.RejoindreNouvelEvenementAsync("Camille");

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.MemberJoined));
        Assert.Equal("Camille", ligne.ActorName);
        Assert.Null(ligne.Payload);
    }

    [Fact]
    public async Task Changer_de_statut_consigne_l_ancien_et_le_nouveau()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        await essai.RepondrePresenceAsync(evenementId, "Yes");

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.MemberStatusChanged));
        Assert.Contains("\"de\":\"Unknown\"", ligne.Payload);
        Assert.Contains("\"vers\":\"Yes\"", ligne.Payload);
    }

    [Fact]
    public async Task Changer_la_date_consigne_le_champ_touche()
    {
        // Sans ce payload, l'application ne peut pas distinguer un changement de date
        // d'un changement de lieu : les deux catégories n'en font qu'une.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        await essai.ModifierDateAsync(evenementId, DateTimeOffset.Parse("2026-12-31T20:00:00Z"));

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.EventDateOrPlaceChanged));
        Assert.Contains("date", ligne.Payload);
        Assert.DoesNotContain("lieu", ligne.Payload);
    }
}
```

Adapter les noms des aides à ceux réellement présents dans la fixture d'intégration.

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteEventsTests
```

Attendu : le troisième test ÉCHOUE — `Payload` est `null` sur
`event.date_or_place_changed` aujourd'hui. Les deux premiers peuvent passer d'emblée :
c'est normal, ils protègent la bascule qui suit.

- [ ] **Étape 3 : Injecter le contrat dans les trois services**

Ajouter `IJournalActivite journal` au constructeur primaire de `JoinService`,
`AttendanceService` et `EventService`, puis remplacer chaque bloc
`db.ActivityEntries.Add(new ActivityEntry { … })` par un appel au contrat. Exemple pour
`JoinService.cs:157` :

```csharp
journal.Consigner(
    evenement.Id,
    membre.Id,
    membre.DisplayName,
    ActivityKinds.MemberJoined);
```

Pour `AttendanceService.cs:141` :

```csharp
journal.Consigner(
    eventId,
    membre.Id,
    membre.DisplayName,
    ActivityKinds.MemberStatusChanged,
    new { de = ancien, vers = statut });
```

Le `SaveChangesAsync` qui suit chaque bloc reste **inchangé** : c'est lui qui valide.

- [ ] **Étape 4 : Ajouter le payload du changement de date ou de lieu**

Dans `EventService.cs`, autour de la ligne 304, la condition qui déclenche l'écriture
sait déjà ce qui a changé. Construire la liste et la passer :

```csharp
var champs = new List<string>();
if (dateModifiee)
{
    champs.Add("date");
}

if (lieuModifie)
{
    champs.Add("lieu");
}

if (champs.Count > 0)
{
    journal.Consigner(
        evenement.Id,
        acteur.Id,
        acteur.DisplayName,
        ActivityKinds.EventDateOrPlaceChanged,
        new { champs });
}
```

Reprendre les noms réels des variables locales qui portent déjà ces deux booléens dans
la méthode ; ne pas en introduire de nouveaux si la condition existante les nomme
autrement.

- [ ] **Étape 5 : Lancer, vérifier que tout passe**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteEventsTests
cd api && dotnet test tests/PartyPlan.IntegrationTests
```

Attendu : 3 tests PASS, et **aucune régression** sur la suite d'intégration complète.

- [ ] **Étape 6 : Vérifier qu'aucun module n'ajoute plus directement**

```bash
grep -rn "ActivityEntries.Add" api/src --include=*.cs | grep -v Infrastructure/Journal
```

Attendu : **aucune sortie**. Le seul point d'écriture est désormais `JournalActivite`.

- [ ] **Étape 7 : Commit**

```bash
git add api/src/PartyPlan.Modules.Events api/tests/PartyPlan.IntegrationTests/FilActiviteEventsTests.cs
git commit -m "feat(fil): les trois écritures existantes passent par le contrat

Et la modification de date ou de lieu porte enfin son payload : sans lui,
l'application ne peut pas distinguer un changement de date d'un changement
de lieu, et les deux catégories n'en font qu'une à l'affichage."
```

---

## Tâche 4 : Les cinq écritures de `Shopping`

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Shopping/Application/ShoppingService.cs`
  (constructeur ligne 54, puis `AjouterAsync:128`, `SupprimerAsync:226`,
  `AttribuerAsync:266`, `LibererAsync:308`, `AcheterAsync:350`)
- Test : `api/tests/PartyPlan.IntegrationTests/FilActiviteShoppingTests.cs` (créer)

**Interfaces :**
- Consomme : `IJournalActivite.Consigner` (tâche 2), `ActivityKinds` (tâche 1).
- Produit : payloads `{"libelle": …}` et `{"libelle": …, "montant": …}`, consommés par la
  tâche 10.

- [ ] **Étape 1 : Écrire les tests**

```csharp
namespace PartyPlan.IntegrationTests;

using PartyPlan.Modules.Events.Domain;

public sealed class FilActiviteShoppingTests(BaseDeDonneesFixture fixture)
    : IClassFixture<BaseDeDonneesFixture>
{
    [Fact]
    public async Task Ajouter_un_article_consigne_son_libelle()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        await essai.AjouterArticleAsync(evenementId, "Glaçons");

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ItemCreated));
        Assert.Contains("Glaçons", ligne.Payload);
    }

    [Fact]
    public async Task Supprimer_un_article_consigne_son_libelle()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();
        var articleId = await essai.AjouterArticleAsync(evenementId, "Glaçons");

        await essai.SupprimerArticleAsync(evenementId, articleId);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ItemDeleted));
        Assert.Contains("Glaçons", ligne.Payload);
    }

    [Fact]
    public async Task Attribuer_puis_liberer_consigne_les_deux_mouvements()
    {
        // La libération est la moitié qui manquait : sans elle, le fil montre un article
        // pris en charge par quelqu'un qui l'a relâché depuis.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();
        var articleId = await essai.AjouterArticleAsync(evenementId, "Glaçons");

        await essai.AttribuerArticleAsync(evenementId, articleId);
        await essai.LibererArticleAsync(evenementId, articleId);

        var lignes = await essai.LireActivitesAsync(evenementId);
        Assert.Single(lignes.Where(a => a.Kind == ActivityKinds.ItemClaimed));
        Assert.Single(lignes.Where(a => a.Kind == ActivityKinds.ItemUnclaimed));
    }

    [Fact]
    public async Task Acheter_consigne_le_libelle_et_le_montant()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();
        var articleId = await essai.AjouterArticleAsync(evenementId, "Glaçons");

        await essai.AcheterArticleAsync(evenementId, articleId, 4.50m);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ItemPurchased));
        Assert.Contains("Glaçons", ligne.Payload);
        Assert.Contains("4.5", ligne.Payload);
    }

    [Fact]
    public async Task Un_ajout_refuse_ne_laisse_aucune_ligne()
    {
        // La garantie de transaction, éprouvée sur un vrai service : un libellé vide est
        // rejeté par la validation, et rien ne doit rester.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        await essai.AjouterArticleAttenduEnEchecAsync(evenementId, "   ");

        Assert.Empty(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ItemCreated));
    }
}
```

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteShoppingTests
```

Attendu : les quatre premiers ÉCHOUENT (aucune ligne écrite). Le cinquième passe déjà —
il verrouille le comportement pour la suite.

- [ ] **Étape 3 : Injecter le contrat**

Ajouter `IJournalActivite journal` au constructeur primaire de `ShoppingService`
(ligne 54), après `IDiffusionEvenement diffusion`.

- [ ] **Étape 4 : Consigner dans les cinq méthodes**

**Toujours avant le `SaveChangesAsync`**, jamais après. Dans `AjouterAsync`, juste avant
`await db.SaveChangesAsync(...)` :

```csharp
journal.Consigner(
    eventId,
    moi.MemberId,
    moi.DisplayName,
    ActivityKinds.ItemCreated,
    new { libelle = article.Name });
```

`SupprimerAsync` — capturer le libellé **avant** de retirer l'article, sinon il est
perdu :

```csharp
journal.Consigner(
    eventId,
    moi.MemberId,
    moi.DisplayName,
    ActivityKinds.ItemDeleted,
    new { libelle = article.Name });
```

`AttribuerAsync` :

```csharp
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.ItemClaimed, new { libelle = article.Name });
```

`LibererAsync` :

```csharp
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.ItemUnclaimed, new { libelle = article.Name });
```

`AcheterAsync` — le montant réel s'il est fourni, sinon le libellé seul :

```csharp
journal.Consigner(
    eventId,
    moi.MemberId,
    moi.DisplayName,
    ActivityKinds.ItemPurchased,
    requete.ActualPrice is { } prix
        ? new { libelle = article.Name, montant = prix }
        : (object)new { libelle = article.Name });
```

- [ ] **Étape 5 : Lancer, vérifier que tout passe**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteShoppingTests
cd api && dotnet test
```

Attendu : 5 tests PASS, aucune régression sur l'ensemble.

- [ ] **Étape 6 : Commit**

```bash
git add api/src/PartyPlan.Modules.Shopping api/tests/PartyPlan.IntegrationTests/FilActiviteShoppingTests.cs
git commit -m "feat(fil): les courses alimentent le fil, libération comprise"
```

---

## Tâche 5 : Les trois écritures d'`Expenses`

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Expenses/Application/ExpenseService.cs`
  (`CreerAsync:253`, `ModifierAsync:316`, `SupprimerAsync:401`)
- Test : `api/tests/PartyPlan.IntegrationTests/FilActiviteExpensesTests.cs` (créer)

**Interfaces :**
- Consomme : `IJournalActivite.Consigner` (tâche 2), `ActivityKinds` (tâche 1).
- Produit : payload `{"libelle", "montant"}` et `{"libelle", "ancienMontant", "montant"}`.

- [ ] **Étape 1 : Écrire les tests**

```csharp
namespace PartyPlan.IntegrationTests;

using PartyPlan.Modules.Events.Domain;

public sealed class FilActiviteExpensesTests(BaseDeDonneesFixture fixture)
    : IClassFixture<BaseDeDonneesFixture>
{
    [Fact]
    public async Task Creer_une_depense_consigne_libelle_et_montant()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        await essai.CreerDepenseAsync(evenementId, "Courses", 62.40m);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ExpenseCreated));
        Assert.Contains("Courses", ligne.Payload);
        Assert.Contains("62.4", ligne.Payload);
    }

    [Fact]
    public async Task Modifier_une_depense_consigne_l_ancien_et_le_nouveau_montant()
    {
        // Les deux montants, parce que c'est la question posée en cas de litige :
        // combien c'était avant.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();
        var depenseId = await essai.CreerDepenseAsync(evenementId, "Courses", 62.40m);

        await essai.ModifierDepenseAsync(evenementId, depenseId, "Courses", 58.10m);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ExpenseUpdated));
        Assert.Contains("\"ancienMontant\":62.4", ligne.Payload);
        Assert.Contains("\"montant\":58.1", ligne.Payload);
    }

    [Fact]
    public async Task Supprimer_une_depense_consigne_sa_disparition()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();
        var depenseId = await essai.CreerDepenseAsync(evenementId, "Courses", 62.40m);

        await essai.SupprimerDepenseAsync(evenementId, depenseId);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(evenementId))
                .Where(a => a.Kind == ActivityKinds.ExpenseDeleted));
        Assert.Contains("Courses", ligne.Payload);
        Assert.Contains("62.4", ligne.Payload);
    }
}
```

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteExpensesTests
```

Attendu : 3 ÉCHECS.

- [ ] **Étape 3 : Injecter et consigner**

Ajouter `IJournalActivite journal` au constructeur primaire de `ExpenseService`, puis,
avant chaque `SaveChangesAsync` :

```csharp
// CreerAsync
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.ExpenseCreated,
    new { libelle = depense.Label, montant = depense.Amount });

// ModifierAsync — capturer ancienMontant AVANT d'écraser la valeur
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.ExpenseUpdated,
    new { libelle = depense.Label, ancienMontant = montantAvant, montant = depense.Amount });

// SupprimerAsync
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.ExpenseDeleted,
    new { libelle = depense.Label, montant = depense.Amount });
```

Reprendre les noms réels des propriétés de l'entité `Expense` (`Label`/`Amount` ou leurs
équivalents) en les lisant dans le fichier.

- [ ] **Étape 4 : Lancer, vérifier que tout passe**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteExpensesTests
cd api && dotnet test
```

Attendu : 3 PASS, aucune régression — en particulier **aucune** sur les tests de
remboursement, qui sont le domaine le plus sensible du produit.

- [ ] **Étape 5 : Commit**

```bash
git add api/src/PartyPlan.Modules.Expenses api/tests/PartyPlan.IntegrationTests/FilActiviteExpensesTests.cs
git commit -m "feat(fil): les dépenses alimentent le fil, suppression comprise"
```

---

## Tâche 6 : Les deux écritures de `Settlements`

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Settlements/Application/SettlementService.cs`
  (`MarquerAsync:179`, `AnnulerAsync:237`)
- Test : `api/tests/PartyPlan.IntegrationTests/FilActiviteSettlementsTests.cs` (créer)

**Interfaces :**
- Consomme : `IJournalActivite.Consigner` (tâche 2), `ActivityKinds` (tâche 1).
- Produit : payload `{"vers": "<nom du créancier>", "montant": <decimal>}`.

- [ ] **Étape 1 : Écrire les tests**

```csharp
namespace PartyPlan.IntegrationTests;

using PartyPlan.Modules.Events.Domain;

public sealed class FilActiviteSettlementsTests(BaseDeDonneesFixture fixture)
    : IClassFixture<BaseDeDonneesFixture>
{
    [Fact]
    public async Task Marquer_un_remboursement_consigne_le_creancier_et_le_montant()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var dossier = await essai.CreerDetteEntreDeuxMembresAsync();

        await essai.MarquerRemboursementAsync(dossier.EvenementId, dossier.CreancierId);

        var ligne = Assert.Single(
            (await essai.LireActivitesAsync(dossier.EvenementId))
                .Where(a => a.Kind == ActivityKinds.SettlementMarked));
        Assert.Contains(dossier.NomCreancier, ligne.Payload);
    }

    [Fact]
    public async Task Annuler_un_remboursement_le_consigne_aussi()
    {
        // Le cas qui fait le litige : quelqu'un annule un remboursement marqué. Sans
        // cette ligne, le fil affirme que la dette a été réglée et se tait sur la suite.
        await using var essai = await fixture.NouvelEssaiAsync();
        var dossier = await essai.CreerDetteEntreDeuxMembresAsync();
        await essai.MarquerRemboursementAsync(dossier.EvenementId, dossier.CreancierId);

        await essai.AnnulerRemboursementAsync(dossier.EvenementId, dossier.CreancierId);

        var lignes = await essai.LireActivitesAsync(dossier.EvenementId);
        Assert.Single(lignes.Where(a => a.Kind == ActivityKinds.SettlementMarked));
        Assert.Single(lignes.Where(a => a.Kind == ActivityKinds.SettlementCancelled));
    }
}
```

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteSettlementsTests
```

Attendu : 2 ÉCHECS.

- [ ] **Étape 3 : Injecter et consigner**

Ajouter `IJournalActivite journal` au constructeur primaire de `SettlementService`, puis
avant chaque `SaveChangesAsync` :

```csharp
journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.SettlementMarked,
    new { vers = creancier.DisplayName, montant });

journal.Consigner(
    eventId, moi.MemberId, moi.DisplayName,
    ActivityKinds.SettlementCancelled,
    new { vers = creancier.DisplayName, montant });
```

- [ ] **Étape 4 : Lancer la suite complète**

```bash
cd api && dotnet test
```

Attendu : tout PASS. **Le jeu de référence du `§6.5` doit rester vert** — s'il rougit,
arrêter et appliquer `superpowers:systematic-debugging` avant toute correction.

- [ ] **Étape 5 : Commit**

```bash
git add api/src/PartyPlan.Modules.Settlements api/tests/PartyPlan.IntegrationTests/FilActiviteSettlementsTests.cs
git commit -m "feat(fil): les remboursements alimentent le fil, annulation comprise"
```

---

## Tâche 7 : L'endpoint de lecture

**Fichiers :**
- Créer : `api/src/PartyPlan.Modules.Events/Application/ActivityService.cs`
- Modifier : `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs`
- Modifier : `api/src/PartyPlan.Modules.Events/EventsModule.cs` (enregistrement du
  service, suivre le motif des services déjà enregistrés)
- Test : `api/tests/PartyPlan.IntegrationTests/FilActiviteLectureTests.cs` (créer)

**Interfaces :**
- Consomme : `ActivityEntry` (tâche 1), `IEventMembership`.
- Produit : `ActivityPage(IReadOnlyList<ActivityView> Items, bool HasMore)` et
  `ActivityView(Guid Id, Guid? MemberId, string ActorName, string? AvatarUrl, string Kind,
  JsonElement? Donnees, DateTimeOffset CreatedAt)`, consommés par la tâche 9.

- [ ] **Étape 1 : Écrire les tests**

```csharp
namespace PartyPlan.IntegrationTests;

public sealed class FilActiviteLectureTests(ApiFixture fixture)
    : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Un_non_membre_recoit_404()
    {
        // RG-SEC-02 : jamais 403. Un 403 confirmerait l'existence de l'événement.
        await using var essai = await fixture.NouvelEssaiAsync();
        var evenementId = await essai.CreerEvenementChezQuelqunDAutreAsync();

        var reponse = await essai.ClientConnecte.GetAsync(
            $"/v1/events/{evenementId}/activity",
            TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.NotFound, reponse.StatusCode);
    }

    [Fact]
    public async Task Un_administrateur_plateforme_non_membre_recoit_404()
    {
        // Règle 2, RG-ADM-01 : sans elle, la promesse d'événement privé est fausse.
        await using var essai = await fixture.NouvelEssaiAsync();
        var evenementId = await essai.CreerEvenementChezQuelqunDAutreAsync();

        var reponse = await essai.ClientAdministrateur.GetAsync(
            $"/v1/events/{evenementId}/activity",
            TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.NotFound, reponse.StatusCode);
    }

    [Fact]
    public async Task La_page_est_rendue_du_plus_recent_au_plus_ancien()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var evenementId = await essai.EvenementAvecTroisArticlesAsync();

        var page = await essai.LirePageActiviteAsync(evenementId, limite: 30);

        Assert.False(page.HasMore);
        Assert.True(
            page.Items[0].CreatedAt >= page.Items[^1].CreatedAt,
            "Le fil doit descendre du plus récent au plus ancien.");
    }

    [Fact]
    public async Task Le_curseur_ne_recouvre_ni_n_omet_aucune_ligne()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var evenementId = await essai.EvenementAvecDouzeActivitesAsync();

        var premiere = await essai.LirePageActiviteAsync(evenementId, limite: 5);
        var seconde = await essai.LirePageActiviteAsync(
            evenementId, limite: 5, avant: premiere.Items[^1].Id);
        var troisieme = await essai.LirePageActiviteAsync(
            evenementId, limite: 5, avant: seconde.Items[^1].Id);

        Assert.True(premiere.HasMore);
        Assert.True(seconde.HasMore);
        Assert.False(troisieme.HasMore);

        var identifiants = premiere.Items
            .Concat(seconde.Items)
            .Concat(troisieme.Items)
            .Select(a => a.Id)
            .ToList();
        Assert.Equal(12, identifiants.Count);
        Assert.Equal(12, identifiants.Distinct().Count());
    }

    [Fact]
    public async Task Une_limite_au_dela_du_plafond_est_refusee()
    {
        // Vérifié avant lecture : accepter puis rejeter ferait payer la requête.
        await using var essai = await fixture.NouvelEssaiAsync();
        var (evenementId, _) = await essai.CreerEvenementAvecMembreAsync();

        var reponse = await essai.ClientConnecte.GetAsync(
            $"/v1/events/{evenementId}/activity?limit=5000",
            TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.BadRequest, reponse.StatusCode);
    }
}
```

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteLectureTests
```

Attendu : ÉCHECS — l'endpoint n'existe pas (404 partout, y compris là où l'on attend
autre chose).

- [ ] **Étape 3 : Écrire le service**

Créer `api/src/PartyPlan.Modules.Events/Application/ActivityService.cs` :

```csharp
namespace PartyPlan.Modules.Events.Application;

using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Results;

/// <summary>Une ligne du fil, telle que l'application la reçoit.</summary>
public sealed record ActivityView(
    Guid Id,
    Guid? MemberId,
    string ActorName,
    string? AvatarUrl,
    string Kind,
    JsonElement? Donnees,
    DateTimeOffset CreatedAt);

/// <summary>
/// Une page du fil, du plus récent au plus ancien.
/// <para>
/// <paramref name="HasMore"/> dit s'il reste des lignes plus anciennes. Sans lui,
/// l'application redemanderait indéfiniment une page qui n'existe pas.
/// </para>
/// </summary>
public sealed record ActivityPage(IReadOnlyList<ActivityView> Items, bool HasMore);

/// <summary>
/// Lecture du fil d'activité (EF-FIL-01). Aucune écriture : le fil est alimenté par
/// <see cref="IJournalActivite"/>, depuis les modules qui agissent.
/// </summary>
public sealed class ActivityService(
    IEventsDbContext db,
    IEventMembership membership)
{
    /// <summary>Plafond de lecture, vérifié avant toute requête.</summary>
    public const int LimiteMaximale = 100;

    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError LimiteInvalide = DomainError.Validation(
        "activity.limit_invalid",
        $"La limite doit être comprise entre 1 et {LimiteMaximale}.");

    public async Task<Result<ActivityPage>> ListerAsync(
        Guid eventId,
        Guid? avant,
        int limite,
        CancellationToken cancellationToken)
    {
        if (limite is < 1 or > LimiteMaximale)
        {
            return LimiteInvalide;
        }

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var requete = db.ActivityEntries.Where(a => a.EventId == eventId);

        if (avant is { } curseur)
        {
            // Le curseur porte sur l'horodatage, l'identifiant ne départageant que les
            // ex æquo : deux lignes de la même milliseconde sont le cas normal d'une
            // action qui en consigne plusieurs.
            var repere = await db.ActivityEntries
                .Where(a => a.Id == curseur)
                .Select(a => new { a.CreatedAt, a.Id })
                .FirstOrDefaultAsync(cancellationToken)
                .ConfigureAwait(false);

            if (repere is not null)
            {
                requete = requete.Where(a =>
                    a.CreatedAt < repere.CreatedAt
                    || (a.CreatedAt == repere.CreatedAt && a.Id.CompareTo(repere.Id) < 0));
            }
        }

        // Une ligne de plus que demandé : sa présence répond HasMore sans compter la
        // table entière à chaque page.
        var lignes = await requete
            .OrderByDescending(a => a.CreatedAt)
            .ThenByDescending(a => a.Id)
            .Take(limite + 1)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var encore = lignes.Count > limite;
        if (encore)
        {
            lignes.RemoveAt(lignes.Count - 1);
        }

        var membres = (await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false))
            .ToDictionary(m => m.MemberId, m => m.AvatarUrl);

        var vues = lignes.Select(a => new ActivityView(
            a.Id,
            a.MemberId,
            // ActorName est figé à l'écriture (RG-USR-04) : un changement de nom ne
            // réécrit pas l'histoire. La photo, elle, est celle d'aujourd'hui — c'est
            // ainsi qu'on reconnaît la personne.
            a.ActorName,
            a.MemberId is { } id && membres.TryGetValue(id, out var avatar) ? avatar : null,
            a.Kind,
            a.Payload is null ? null : JsonDocument.Parse(a.Payload).RootElement,
            a.CreatedAt)).ToList();

        return new ActivityPage(vues, encore);
    }
}
```

Adapter `DomainError.Validation` et `Result<T>` aux noms réels du `SharedKernel` en les
lisant dans un service voisin.

- [ ] **Étape 4 : Exposer l'endpoint**

Dans `EventsEndpoints.cs`, en suivant le motif de `MessagesEndpoints.cs:47` :

```csharp
groupe.MapGet("/{eventId:guid}/activity", async (
        Guid eventId,
        Guid? before,
        int? limit,
        ActivityService service,
        CancellationToken cancellationToken) =>
    {
        var resultat = await service
            .ListerAsync(eventId, before, limit ?? 30, cancellationToken)
            .ConfigureAwait(false);
        return resultat.ToHttpResult();
    })
    .WithSummary("Fil d'activité de l'événement")
    .WithDescription(
        "Trié du plus récent au plus ancien. `before` remonte vers le passé. "
        + "Lecture seule : le fil ne se modifie pas, y compris pour le propriétaire "
        + "(RG-FIL-02).");
```

Reprendre `ToHttpResult` ou l'équivalent réellement utilisé par les endpoints voisins.

- [ ] **Étape 5 : Lancer, vérifier que tout passe**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FilActiviteLectureTests
```

Attendu : 5 PASS.

- [ ] **Étape 6 : Régénérer le contrat OpenAPI**

```bash
make up
curl -s http://localhost:5080/openapi/v1.json > docs/api/openapi.json
```

Vérifier que `/v1/events/{eventId}/activity` y figure.

- [ ] **Étape 7 : Commit**

```bash
git add api/src/PartyPlan.Modules.Events api/tests/PartyPlan.IntegrationTests/FilActiviteLectureTests.cs docs/api/openapi.json
git commit -m "feat(fil): lecture du fil, pagination par curseur

Convention identique à celle de la discussion : deux paginations
différentes obligeraient à se souvenir laquelle s'applique où.

Le curseur porte sur l'horodatage, l'identifiant départageant les ex æquo —
une action qui consigne plusieurs lignes les écrit dans la même milliseconde."
```

---

## Tâche 8 : Diffuser `activity.appended` — fermeture du lot 1.6

**Fichiers :**
- Modifier : les quatre services journalisant (Events, Shopping, Expenses, Settlements)
- Test : `api/tests/PartyPlan.IntegrationTests/TempsReelDeuxClientsTests.cs` (créer)
- Modifier : `docs/roadmap.md` (lot 1.6)

**Interfaces :**
- Consomme : `IDiffusionEvenement.PublierAsync`, `MessagesTempsReel.ActiviteAjoutee`
  (existant), `ActivityView` (tâche 7).

- [ ] **Étape 1 : Écrire le test à deux clients**

```csharp
namespace PartyPlan.IntegrationTests;

using Microsoft.AspNetCore.SignalR.Client;

public sealed class TempsReelDeuxClientsTests(ApiFixture fixture)
    : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Ce_qu_un_membre_fait_parvient_a_l_autre()
    {
        await using var essai = await fixture.NouvelEssaiAsync();
        var soiree = await essai.EvenementAvecDeuxMembresAsync();

        await using var alex = await essai.ConnecterAuHubAsync(soiree.Id, soiree.Alex);
        await using var camille = await essai.ConnecterAuHubAsync(soiree.Id, soiree.Camille);

        var recus = new List<string>();
        var attendu = new TaskCompletionSource();
        camille.On<string, object>("Changement", (message, _) =>
        {
            recus.Add(message);
            if (recus.Contains("activity.appended") && recus.Contains("item.created"))
            {
                attendu.TrySetResult();
            }
        });

        await essai.AjouterArticleAsync(soiree.Id, "Glaçons", parLeCompte: soiree.Alex);

        await attendu.Task.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);

        // Deux messages, volontairement : l'écran des courses et l'écran du fil ne
        // lisent pas la même chose.
        Assert.Contains("item.created", recus);
        Assert.Contains("activity.appended", recus);
    }

    [Fact]
    public async Task Un_non_membre_ne_rejoint_aucun_groupe()
    {
        // RG-SEC-02 : la connexion est abandonnée sans message distinctif.
        await using var essai = await fixture.NouvelEssaiAsync();
        var soiree = await essai.EvenementAvecDeuxMembresAsync();
        var intrus = await essai.NouveauCompteAsync();

        await using var connexion = await essai.ConnecterAuHubAsync(soiree.Id, intrus);

        var recus = new List<string>();
        connexion.On<string, object>("Changement", (message, _) => recus.Add(message));

        await essai.AjouterArticleAsync(soiree.Id, "Glaçons", parLeCompte: soiree.Alex);
        await Task.Delay(TimeSpan.FromSeconds(1), TestContext.Current.CancellationToken);

        Assert.Empty(recus);
    }
}
```

Reprendre la mise en place du hub réellement utilisée par les tests SignalR déjà présents
(chercher `HubConnectionBuilder` dans `api/tests`), notamment le passage du jeton en
chaîne de requête, corrigé au commit `b84bf83`.

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter TempsReelDeuxClientsTests
```

Attendu : le premier ÉCHOUE par expiration — `activity.appended` n'est jamais diffusé.
Le second passe déjà : il verrouille le cloisonnement du hub.

- [ ] **Étape 3 : Diffuser après validation**

Dans chaque service, **après** le `SaveChangesAsync` et à côté de la diffusion métier
déjà présente, publier la ligne consignée. Exemple pour `ShoppingService.AjouterAsync` :

```csharp
await diffusion
    .PublierAsync(
        eventId,
        MessagesTempsReel.ActiviteAjoutee,
        new
        {
            memberId = moi.MemberId,
            actorName = moi.DisplayName,
            avatarUrl = moi.AvatarUrl,
            kind = ActivityKinds.ItemCreated,
            donnees = new { libelle = article.Name },
            createdAt = clock.UtcNow,
        },
        cancellationToken)
    .ConfigureAwait(false);
```

La diffusion ne peut pas partir de `Consigner`, qui s'exécute avant validation : elle
annoncerait une entrée que la transaction peut encore annuler.

Pour éviter treize répétitions, ajouter dans chaque service une aide privée
`DiffuserActiviteAsync(Guid eventId, string kind, object? donnees, CancellationToken)`
sur le modèle du `DiffuserAsync` existant de `ShoppingService:490`.

- [ ] **Étape 4 : Lancer, vérifier que tout passe**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter TempsReelDeuxClientsTests
cd api && dotnet test
```

Attendu : 2 PASS, aucune régression.

- [ ] **Étape 5 : Mettre la feuille de route à jour honnêtement**

Dans `docs/roadmap.md`, lot 1.6 : cocher `activity.appended`, et **réécrire les deux
lignes de recette** plutôt que de les cocher :

```markdown
- [x] `activity.appended` — diffusé par les quatre modules qui journalisent, vérifié par
      un test à deux clients SignalR
- [ ] Recette : propagation en moins d'une seconde — `NF-PERF-05`
  - → un test à deux clients couvre la **logique** de diffusion, pas la latence : deux
    connexions dans le même processus ne mesurent ni un vrai réseau ni un vrai appareil.
    La mesure remonte au lot 1.17, avec les autres recettes matérielles
- [ ] Recette : coupure réseau puis rétablissement — même motif, exige deux appareils
```

- [ ] **Étape 6 : Commit**

```bash
git add api/src api/tests docs/roadmap.md
git commit -m "feat(temps-reel): activity.appended, et un test à deux clients

Ferme la dernière ligne de code du lot 1.6.

La recette NF-PERF-05 reste ouverte et remonte au lot 1.17 : deux connexions
dans le même processus mesurent la logique de diffusion, pas la latence sur
un vrai réseau. La cocher ici ferait croire la performance vérifiée."
```

---

## Tâche 9 : Le modèle et l'API côté application

**Fichiers :**
- Créer : `app/lib/core/models/activite.dart`
- Créer : `app/lib/core/network/activite_api.dart`
- Test : `app/test/core/models/activite_test.dart` (créer)

**Interfaces :**
- Consomme : `ActivityPage` de la tâche 7.
- Produit : `Activite`, `PageActivite`, `ActiviteApi.lire(...)` et le provider familial
  `filActiviteProvider` (clé : identifiant d'événement, valeur : `Future<PageActivite>`),
  consommés par les tâches 10 et 11.

- [ ] **Étape 1 : Écrire le test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';

void main() {
  group('Activite.depuisJson', () {
    test('lit une ligne complète', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'memberId': 'm1',
        'actorName': 'Camille',
        'avatarUrl': null,
        'kind': 'item.claimed',
        'donnees': {'libelle': 'Glaçons'},
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.auteur, 'Camille');
      expect(activite.categorie, 'item.claimed');
      expect(activite.texte('libelle'), 'Glaçons');
    });

    test('accepte une ligne sans données', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'member.joined',
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.texte('libelle'), isNull);
      expect(activite.montant('montant'), isNull);
    });

    test('ne plante pas sur un champ absent du payload', () {
      // Une entrée écrite par une version antérieure du serveur ne doit jamais casser
      // l'écran : le fil est en ajout seul, ces lignes ne seront jamais corrigées.
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'expense.created',
        'donnees': {'libelle': 'Courses'},
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.texte('libelle'), 'Courses');
      expect(activite.montant('montant'), isNull);
    });
  });
}
```

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd app && flutter test test/core/models/activite_test.dart
```

Attendu : ÉCHEC — `activite.dart` n'existe pas.

- [ ] **Étape 3 : Écrire le modèle**

Créer `app/lib/core/models/activite.dart` :

```dart
/// Une ligne du fil d'activité (`EF-FIL-01`).
///
/// Le serveur envoie des données, jamais une phrase : la ligne est inaltérable en base
/// (`RG-FIL-02`), et une formulation stockée y resterait pour toujours. La phrase est
/// composée à l'affichage, depuis [categorie] et [donnees].
class Activite {
  const Activite({
    required this.id,
    required this.auteur,
    required this.categorie,
    required this.creeLe,
    this.membreId,
    this.avatarUrl,
    this.donnees,
  });

  factory Activite.depuisJson(Map<String, dynamic> json) => Activite(
    id: json['id'] as String,
    membreId: json['memberId'] as String?,
    auteur: json['actorName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    categorie: json['kind'] as String? ?? '',
    donnees: json['donnees'] as Map<String, dynamic>?,
    creeLe: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String? membreId;

  /// Nom figé à l'écriture : un changement de nom ne réécrit pas l'histoire
  /// (`RG-USR-04`).
  final String auteur;

  final String? avatarUrl;
  final String categorie;
  final Map<String, dynamic>? donnees;
  final DateTime creeLe;

  /// Champ texte du payload, ou `null` s'il manque. Ne lève jamais : une ligne écrite
  /// par une version antérieure du serveur ne doit pas casser l'écran.
  String? texte(String cle) => donnees?[cle] as String?;

  /// Champ montant du payload. Affichage seul — le fil n'additionne rien, et ce nombre
  /// n'est jamais une source de calcul.
  double? montant(String cle) => (donnees?[cle] as num?)?.toDouble();

  /// Liste de chaînes du payload, pour `event.date_or_place_changed`.
  List<String> liste(String cle) =>
      (donnees?[cle] as List<dynamic>?)?.cast<String>() ?? const [];
}

/// Une page du fil, du plus récent au plus ancien.
class PageActivite {
  const PageActivite({required this.lignes, required this.encore});

  factory PageActivite.depuisJson(Map<String, dynamic> json) => PageActivite(
    lignes: ((json['items'] as List<dynamic>?) ?? const [])
        .map((e) => Activite.depuisJson(e as Map<String, dynamic>))
        .toList(),
    encore: json['hasMore'] as bool? ?? false,
  );

  final List<Activite> lignes;

  /// Reste-t-il des lignes plus anciennes à demander.
  final bool encore;
}
```

- [ ] **Étape 4 : Écrire le client d'API**

Créer `app/lib/core/network/activite_api.dart`, sur le modèle de `discussion_api.dart` :

```dart
import '../models/activite.dart';
import 'api_client.dart';

/// Appels d'API du fil d'activité (`§8.2`).
class ActiviteApi {
  const ActiviteApi(this._client);

  final ApiClient _client;

  /// Une page du fil : les dernières lignes, ou celles qui précèdent [avant].
  ///
  /// Seule la première page est mise en cache : le fil est un journal en lecture seule,
  /// et montrer hors ligne les dernières lignes connues suffit. Mettre en cache les
  /// pages suivantes obligerait à remplacer `shared_preferences`, ce qui est un lot en
  /// soi (limite consignée au lot 1.12).
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) => _client.get(
    '/events/$evenementId/activity?limit=$limite'
    '${avant == null ? '' : '&before=$avant'}',
    cacheable: avant == null,
    analyser: (corps) =>
        PageActivite.depuisJson(corps! as Map<String, dynamic>),
  );
}
```

- [ ] **Étape 5 : Déclarer le provider**

Dans `app/lib/core/providers.dart`, à côté des providers d'événement existants :

```dart
/// Première page du fil d'activité d'un événement.
///
/// Invalidé par [EcouteEvenement] à chaque message diffusé : `activity.appended` n'a
/// donc besoin d'aucun traitement particulier côté écran.
final filActiviteProvider = FutureProvider.family<PageActivite, String>(
  (ref, evenementId) => ActiviteApi(ref.watch(apiClientProvider)).lire(evenementId),
);
```

Reprendre le nom réel du provider de client HTTP s'il diffère d'`apiClientProvider`.

- [ ] **Étape 6 : Lancer, vérifier que tout passe**

```bash
cd app && flutter test test/core/models/activite_test.dart
```

Attendu : 3 PASS.

- [ ] **Étape 7 : Commit**

```bash
git add app/lib/core/models/activite.dart app/lib/core/network/activite_api.dart app/lib/core/providers.dart app/test/core/models/activite_test.dart
git commit -m "feat(fil): modèle et client d'API du fil d'activité

Seule la première page est mise en cache : un journal en lecture seule n'a
pas besoin d'être intégralement consultable hors ligne, et l'y forcer
imposerait de remplacer shared_preferences dès maintenant."
```

---

## Tâche 10 : L'écran du fil

**Fichiers :**
- Créer : `app/lib/features/activite/activite_page.dart`
- Créer : `app/lib/features/activite/phrase_activite.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Modifier : `app/lib/features/evenement/coquille_evenement.dart` (`_MenuPlus`, ligne 410)
- Modifier : `app/lib/app/router.dart` et le fichier des routes nommées
- Test : `app/test/features/phrase_activite_test.dart` (créer)

**Interfaces :**
- Consomme : `Activite`, `PageActivite`, `ActiviteApi` (tâche 9).
- Produit : `phraseActivite(BuildContext, Activite)` → `InlineSpan`, et `ActivitePage`.

- [ ] **Étape 1 : Ajouter les chaînes ARB**

Dans `app/lib/l10n/arb/app_fr.arb`, treize phrases plus les libellés d'écran. Le nom de
l'auteur est passé en paramètre pour être mis en gras à l'affichage :

```json
"filTitre": "Activité",
"filVide": "Rien ne s'est encore passé ici",
"filVideDetail": "Les arrivées, les courses et les dépenses s'afficheront ici.",
"filToutVoir": "Tout voir",
"filHorsLigne": "Fil affiché depuis la dernière consultation. Les lignes plus anciennes demandent une connexion.",
"filArriveMembre": "a rejoint la soirée",
"filChangeStatut": "a répondu {vers}",
"filAjouteArticle": "a ajouté {libelle}",
"filSupprimeArticle": "a retiré {libelle}",
"filPrendArticle": "a pris {libelle} en charge",
"filLibereArticle": "a relâché {libelle}",
"filAcheteArticle": "a acheté {libelle}",
"filAcheteArticleMontant": "a acheté {libelle} pour {montant}",
"filCreeDepense": "a ajouté la dépense {libelle}, {montant}",
"filModifieDepense": "a modifié {libelle} : {ancien} devient {montant}",
"filSupprimeDepense": "a supprimé la dépense {libelle}, {montant}",
"filMarqueReglement": "a marqué son remboursement à {vers}, {montant}",
"filAnnuleReglement": "a annulé son remboursement à {vers}, {montant}",
"filChangeDate": "a modifié la date",
"filChangeLieu": "a modifié le lieu",
"filChangeDateEtLieu": "a modifié la date et le lieu",
"filActionInconnue": "a fait une action"
```

Ajouter les blocs `@filChangeStatut` etc. décrivant les placeholders, en suivant le
format des entrées paramétrées déjà présentes dans le fichier.

- [ ] **Étape 2 : Écrire le test de composition**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/features/activite/phrase_activite.dart';

import '../aide/monter_ecran.dart';

Activite _ligne(String categorie, [Map<String, dynamic>? donnees]) => Activite(
  id: 'a1',
  auteur: 'Camille',
  categorie: categorie,
  donnees: donnees,
  creeLe: DateTime(2026, 8, 26, 18, 30),
);

void main() {
  testWidgets('compose une phrase pour les treize catégories', (tester) async {
    late BuildContext contexte;
    await monterEcran(
      tester,
      Builder(builder: (ctx) {
        contexte = ctx;
        return const SizedBox();
      }),
    );

    final cas = <Activite>[
      _ligne('member.joined'),
      _ligne('member.status_changed', {'de': 'Unknown', 'vers': 'Yes'}),
      _ligne('item.created', {'libelle': 'Glaçons'}),
      _ligne('item.deleted', {'libelle': 'Glaçons'}),
      _ligne('item.claimed', {'libelle': 'Glaçons'}),
      _ligne('item.unclaimed', {'libelle': 'Glaçons'}),
      _ligne('item.purchased', {'libelle': 'Glaçons', 'montant': 4.5}),
      _ligne('expense.created', {'libelle': 'Courses', 'montant': 62.4}),
      _ligne('expense.updated',
          {'libelle': 'Courses', 'ancienMontant': 62.4, 'montant': 58.1}),
      _ligne('expense.deleted', {'libelle': 'Courses', 'montant': 62.4}),
      _ligne('settlement.marked', {'vers': 'Alex', 'montant': 12.3}),
      _ligne('settlement.cancelled', {'vers': 'Alex', 'montant': 12.3}),
      _ligne('event.date_or_place_changed', {'champs': ['date']}),
    ];

    for (final activite in cas) {
      final phrase = phraseActivite(contexte, activite);
      expect(phrase.toPlainText(), isNotEmpty,
          reason: 'Aucune phrase pour ${activite.categorie}');
      expect(phrase.toPlainText(), contains('Camille'));
    }
  });

  testWidgets('dégrade sans planter sur une catégorie inconnue', (tester) async {
    // Le fil est en ajout seul : une ligne écrite par une version future du serveur
    // restera en base pour toujours. L'écran doit la traverser, pas s'y arrêter.
    late BuildContext contexte;
    await monterEcran(
      tester,
      Builder(builder: (ctx) {
        contexte = ctx;
        return const SizedBox();
      }),
    );

    final phrase = phraseActivite(contexte, _ligne('quelque.chose.de.neuf'));
    expect(phrase.toPlainText(), contains('Camille'));
  });

  testWidgets('dégrade sans planter sur un payload incomplet', (tester) async {
    late BuildContext contexte;
    await monterEcran(
      tester,
      Builder(builder: (ctx) {
        contexte = ctx;
        return const SizedBox();
      }),
    );

    final phrase = phraseActivite(contexte, _ligne('item.created'));
    expect(phrase.toPlainText(), contains('Camille'));
  });
}
```

`monterEcran` et les fabriques vivent dans `app/test/aide/` — les réutiliser, ne pas en
écrire de secondes.

- [ ] **Étape 3 : Lancer, vérifier l'échec**

```bash
cd app && flutter test test/features/activite/phrase_activite_test.dart
```

Attendu : ÉCHEC — `phrase_activite.dart` n'existe pas.

- [ ] **Étape 4 : Écrire la composition**

Créer `app/lib/features/activite/phrase_activite.dart`. La fonction rend un `InlineSpan`
pour que le nom de l'auteur soit en gras et les montants en chiffres tabulaires.

```dart
import 'package:flutter/material.dart';

import '../../core/models/activite.dart';
import '../../design/jetons.dart';
import '../../l10n/generated/app_localizations.dart';

/// Compose la phrase affichée d'une ligne du fil.
///
/// La phrase n'est jamais stockée : la ligne est inaltérable en base (`RG-FIL-02`), une
/// formulation maladroite y resterait pour toujours et le fil ne serait jamais
/// traduisible (`NF-I18N-01`).
///
/// Aucune catégorie ne fait défaut : une ligne écrite par une version future du serveur
/// dégrade vers une phrase générique. C'est un journal en ajout seul — il n'y aura pas
/// de correction rétroactive.
InlineSpan phraseActivite(BuildContext context, Activite activite) {
  final l10n = AppLocalizations.of(context)!;
  final montant = _formateur(context);

  final corps = switch (activite.categorie) {
    'member.joined' => l10n.filArriveMembre,
    'member.status_changed' =>
      l10n.filChangeStatut(_statut(l10n, activite.texte('vers'))),
    'item.created' => l10n.filAjouteArticle(activite.texte('libelle') ?? ''),
    'item.deleted' => l10n.filSupprimeArticle(activite.texte('libelle') ?? ''),
    'item.claimed' => l10n.filPrendArticle(activite.texte('libelle') ?? ''),
    'item.unclaimed' => l10n.filLibereArticle(activite.texte('libelle') ?? ''),
    'item.purchased' => activite.montant('montant') is double prix
        ? l10n.filAcheteArticleMontant(
            activite.texte('libelle') ?? '', montant(prix))
        : l10n.filAcheteArticle(activite.texte('libelle') ?? ''),
    'expense.created' => l10n.filCreeDepense(
        activite.texte('libelle') ?? '', montant(activite.montant('montant'))),
    'expense.updated' => l10n.filModifieDepense(
        activite.texte('libelle') ?? '',
        montant(activite.montant('ancienMontant')),
        montant(activite.montant('montant'))),
    'expense.deleted' => l10n.filSupprimeDepense(
        activite.texte('libelle') ?? '', montant(activite.montant('montant'))),
    'settlement.marked' => l10n.filMarqueReglement(
        activite.texte('vers') ?? '', montant(activite.montant('montant'))),
    'settlement.cancelled' => l10n.filAnnuleReglement(
        activite.texte('vers') ?? '', montant(activite.montant('montant'))),
    'event.date_or_place_changed' => _dateOuLieu(l10n, activite.liste('champs')),
    _ => l10n.filActionInconnue,
  };

  return TextSpan(children: [
    TextSpan(
      text: activite.auteur,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    const TextSpan(text: ' '),
    TextSpan(text: corps),
  ]);
}
```

Compléter `_statut`, `_dateOuLieu` et `_formateur` — ce dernier réutilise le formatage de
`PpMoney` (espace insécable, deux décimales) plutôt que d'en écrire un second.

- [ ] **Étape 5 : Lancer, vérifier que tout passe**

```bash
cd app && flutter gen-l10n && flutter test test/features/activite/phrase_activite_test.dart
```

Attendu : 3 PASS.

- [ ] **Étape 6 : Écrire l'écran**

Créer `app/lib/features/activite/activite_page.dart`. Exigences, toutes vérifiables à
l'œil :

- Liste inversée, chargement de la page suivante au défilement — `ScrollController` qui
  demande `avant: dernier.id` quand `encore` est vrai.
- Chaque ligne : `PpAvatar` de l'auteur, la phrase, l'horodatage relatif via
  `app/lib/core/dates.dart`.
- **Aucun `onTap`, aucun `Dismissible`, aucun menu contextuel** — `RG-FIL-02`.
- États : squelettes au chargement initial, `PpEtatVide` avec `filVide`/`filVideDetail`,
  `PpEtatErreur` avec réessai, bandeau `filHorsLigne` quand la page vient du cache.
- Temps réel : brancher `EcouteEvenement` comme les autres écrans — toute diffusion
  invalide le provider, donc `activity.appended` rafraîchit sans code particulier.
- Aucune couleur, marge ni taille en dur : jetons uniquement.

Avant d'écrire, lire `app/lib/features/discussion/discussion_page.dart` : c'est l'écran
paginé le plus proche, et le fil doit lui ressembler.

- [ ] **Étape 7 : Brancher la route et l'entrée du menu**

Ajouter la route nommée, la `GoRoute` dans `app/lib/app/router.dart` près des autres
routes d'événement, et l'entrée « Activité » dans `_MenuPlus`
(`coquille_evenement.dart:410`), avec l'icône `Icons.history_rounded`.

- [ ] **Étape 8 : Vérifier dans l'application**

```bash
make up
```

Puis suivre la skill `run` : ouvrir une soirée du jeu de démonstration, ajouter un
article, une dépense, marquer un remboursement, et vérifier que chaque action apparaît
dans le fil. Vérifier aussi l'état vide sur une soirée neuve.

- [ ] **Étape 9 : Commit**

```bash
git add app/lib/features/activite app/lib/l10n app/lib/app app/lib/features/evenement/coquille_evenement.dart app/test/features/phrase_activite_test.dart
git commit -m "feat(fil): écran du fil d'activité

La phrase est composée à l'affichage et jamais stockée : le fil est en ajout
seul, une formulation maladroite y resterait pour toujours.

Aucune catégorie ne fait défaut — une ligne écrite par une version future du
serveur dégrade vers une phrase générique plutôt que de casser l'écran."
```

---

## Tâche 11 : Les trois dernières lignes sur le tableau de bord

C'est là que le fil sert le plus : on ouvre l'événement, on voit ce qui a bougé.

**Fichiers :**
- Créer : `app/lib/features/evenement/sections/section_activite.dart`
- Modifier : `app/lib/features/evenement/tableau_de_bord_page.dart`
- Test : `app/test/features/section_activite_test.dart` (créer)

**Interfaces :**
- Consomme : `ActiviteApi.lire` (tâche 9), `phraseActivite` (tâche 10).

- [ ] **Étape 1 : Écrire le test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/sections/section_activite.dart';

import '../aide/monter_ecran.dart';

Activite _ligne(String id, String libelle) => Activite(
  id: id,
  auteur: 'Camille',
  categorie: 'item.created',
  donnees: {'libelle': libelle},
  creeLe: DateTime(2026, 8, 26, 18, 30),
);

Future<void> _monter(WidgetTester tester, List<Activite> lignes) async {
  final conteneur = ProviderContainer(
    overrides: [
      filActiviteProvider.overrideWith(
        (ref, id) async => PageActivite(lignes: lignes, encore: false),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const SectionActivite(evenementId: 'e1'),
    conteneur: conteneur,
  );
}

void main() {
  group('Section activité du tableau de bord', () {
    testWidgets('affiche au plus trois lignes et un lien Tout voir', (
      tester,
    ) async {
      await _monter(tester, [
        _ligne('a1', 'Glaçons'),
        _ligne('a2', 'Chips'),
        _ligne('a3', 'Bière'),
        _ligne('a4', 'Pain'),
        _ligne('a5', 'Nappe'),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Glaçons'), findsOneWidget);
      expect(find.textContaining('Chips'), findsOneWidget);
      expect(find.textContaining('Bière'), findsOneWidget);
      expect(find.textContaining('Pain'), findsNothing);
      expect(find.textContaining('Nappe'), findsNothing);
      expect(find.text('Tout voir'), findsOneWidget);
    });

    testWidgets('reste muette quand le fil est vide', (tester) async {
      // Un bloc « Activité » vide sur le tableau de bord d'une soirée neuve
      // occuperait la place utile sans rien dire. La section disparaît entièrement,
      // plutôt que d'afficher un état vide de plus.
      await _monter(tester, const []);
      await tester.pumpAndSettle();

      expect(find.text('Activité'), findsNothing);
      expect(find.text('Tout voir'), findsNothing);
    });
  });
}
```

`filActiviteProvider` est le provider familial introduit à la tâche 10 — s'il porte un
autre nom dans l'écran, reprendre celui-là plutôt que d'en déclarer un second.

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
cd app && flutter test test/features/evenement/section_activite_test.dart
```

Attendu : ÉCHEC — la section n'existe pas.

- [ ] **Étape 3 : Écrire la section**

`section_activite.dart`, sur le modèle des sections voisines : un `PpCarte` titré
« Activité », trois lignes au plus, un bouton texte `filToutVoir` menant à l'écran
complet. **La section entière disparaît si le fil est vide.**

- [ ] **Étape 4 : L'insérer dans le tableau de bord**

Dans `tableau_de_bord_page.dart`, placer la section **après** la synthèse des présences
et **avant** le partage : ce qui a bougé compte plus qu'un lien d'invitation déjà connu.

- [ ] **Étape 5 : Lancer, vérifier**

```bash
cd app && flutter test
```

Attendu : tout PASS.

- [ ] **Étape 6 : Commit**

```bash
git add app/lib/features/evenement app/test/features/section_activite_test.dart
git commit -m "feat(fil): les trois dernières lignes sur le tableau de bord"
```

---

## Tâche 12 : Vérification et clôture

- [ ] **Étape 1 : Vérification complète**

```bash
make verif
```

Attendu : format C#, format Dart, analyse, frontières de modules, variables d'env, tests
API et tests Flutter — **tout vert**. Ne rien annoncer avant d'avoir la sortie sous les
yeux (`superpowers:verification-before-completion`).

- [ ] **Étape 2 : Recette du parcours événementiel**

```bash
python3 tools/recette/parcours-evenement.py
```

Attendu : les 84 vérifications passent toujours.

- [ ] **Étape 3 : Mettre la feuille de route à jour**

Dans `docs/roadmap.md`, lot 1.10, cocher les cinq lignes et documenter ce qui a été
tranché :

```markdown
## Lot 1.10 — Fil d'activité

**Livré le 26/08/2026.** Alimenté par le contrat `IJournalActivite`, inscrit dans la
transaction de l'action métier — voir
`docs/superpowers/specs/2026-08-26-fil-activite-design.md`.

- [x] `EF-FIL-01` Fil horodaté des actions structurantes
- [x] `RG-FIL-01` Couvrir les catégories listées — **13 et non 10** : la règle a été
      complétée, les trois actions d'annulation (libération d'article, suppression de
      dépense, annulation de remboursement) manquaient
  - → `event.schedule_changed` retiré, mort avec le planning abandonné le 21/08/2026
- [x] `RG-FIL-02` Lecture seule, non modifiable même par le propriétaire — déclencheur
      d'ajout seul, et aucune interaction sur l'écran
- [x] Pagination par curseur — `§8.1`, convention identique à celle de la discussion
- [x] Intégration au tableau de bord — trois dernières lignes, section masquée si vide
- [x] La phrase affichée est composée par l'application, jamais stockée : la ligne étant
      inaltérable, une formulation maladroite y resterait pour toujours
- [ ] Consultation hors ligne au-delà de la première page — demande de remplacer
      `shared_preferences` (limite consignée au lot 1.12), reporté sciemment
```

Mettre à jour le tableau **Avancement** en tête de fichier : le fil d'activité quitte la
colonne « Reste » de la V1.0.

- [ ] **Étape 4 : Commit**

```bash
git add docs/roadmap.md
git commit -m "docs(fil): acter le lot 1.10 livré, et ce qui reste en dépendant"
```

- [ ] **Étape 5 : Revue**

Appliquer `superpowers:requesting-code-review` sur l'ensemble du lot avant toute fusion.
Ne pas fusionner dans `main` ni pousser sans accord explicite.

---

## Ce que ce plan ne fait pas

- **Aucun rattrapage rétroactif** : les événements déjà en base gardent leur fil partiel.
  Reconstruire l'historique produirait des lignes jamais advenues dans un journal qui
  prétend faire preuve. En développement, `make reset-db` régénère un jeu complet.
- **Aucun rapiéçage de l'état local** — reporté au lot 1.6, motif inchangé.
- **Aucun filtre, aucune recherche** dans le fil.
- **Aucun lien d'une ligne vers sa ressource** : un article supprimé n'a plus d'écran.
- **`NF-PERF-05` reste ouverte** et remonte au lot 1.17 : elle demande de vrais appareils.
