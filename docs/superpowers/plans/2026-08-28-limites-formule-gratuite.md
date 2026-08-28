# Limites de la formule gratuite — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans` pour exécuter tâche par tâche. Les étapes
> sont en cases à cocher.

**But** : la formule gratuite plafonne à 3 événements possédés simultanément et 20 membres
par événement ; un `PlatformAdmin` attribue la formule payante à la main ; chacun voit la
sienne.

**Architecture** : un contrat `IFormuleCompte` dans `SharedKernel` laisse le module `Events`
lire la formule d'un compte sans toucher la table `users` (règle 6). Les deux quotas vivent
dans `Events`, dans une unité `QuotaEvenements` testable sans base. Aucune migration :
`users.premium_until` existe depuis le schéma initial.

**Pile** : ASP.NET Core 10, EF Core 10, Npgsql, xUnit + Shouldly, Flutter 3.38 + Riverpod.

**Spec** : `docs/superpowers/specs/2026-08-28-limites-formule-gratuite-design.md`
**Décision** : `docs/adr/0008-limites-formule-gratuite.md`

## Contraintes globales

- Français dans l'interface et la documentation ; anglais dans le code et les identifiants
  de base. Commentaires de code en français, comme le reste du dépôt.
- Commits conventionnels avec périmètre : `feat(premium):`, `test(premium):`.
- TDD strict : test rouge, exécution qui échoue, implémentation minimale, test vert, commit.
- `make verif` (format, analyse, frontières, tests) avant tout push.
- Aucune couleur, aucun rayon, aucun espacement, aucune taille de texte en dur côté Flutter :
  jetons du design system uniquement.
- Dates affichées en JJ/MM/AAAA.
- Quotas : **3** événements possédés simultanément, **20** membres actifs par événement.
- Codes d'erreur exacts : `plan.event_quota_reached`, `plan.member_limit_reached`. Les deux
  en `ErrorKind.Forbidden` (403).
- Action d'audit exacte : `user.plan_changed`.
- `Events` ne référence jamais `PartyPlan.Modules.Users` :
  `tools/verifier-frontieres-modules.sh` doit rester vert.

---

### Tâche 1 : le contrat `IFormuleCompte` et son implémentation

**Fichiers**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IFormuleCompte.cs`
- Créer : `api/src/PartyPlan.Modules.Users/Application/FormuleCompte.cs`
- Modifier : `api/src/PartyPlan.Modules.Users/UsersModule.cs` (méthode `AddServices`)
- Test : `api/tests/PartyPlan.IntegrationTests/FormuleCompteTests.cs`

**Interfaces**
- Consomme : `IUsersDbContext` (`Modules.Users/Persistence`), `IClock`
  (`SharedKernel/Abstractions`), `User.IsPremium(DateTimeOffset)`
  (`Modules.Users/Domain/User.cs:65`).
- Produit : `IFormuleCompte.EstAbonneAsync(Guid, CancellationToken) → Task<bool>` et
  `EstAbonneManyAsync(IReadOnlyCollection<Guid>, CancellationToken) →
  Task<IReadOnlyDictionary<Guid, bool>>`. Consommé par les tâches 2 à 4.

- [ ] **Étape 1 : écrire le test qui échoue**

`api/tests/PartyPlan.IntegrationTests/FormuleCompteTests.cs` :

```csharp
namespace PartyPlan.IntegrationTests;

using Microsoft.Extensions.DependencyInjection;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Le contrat de frontière qui laisse les autres modules lire une formule sans toucher
/// la table des comptes (règle 6).
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FormuleCompteTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Un_compte_sans_echeance_est_gratuit()
    {
        var userId = await fixture.CreerCompteAsync();

        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneAsync(userId, TestContext.Current.CancellationToken))
            .ShouldBeFalse();
    }

    [Fact]
    public async Task Une_echeance_future_rend_le_compte_abonne()
    {
        var userId = await fixture.CreerCompteAsync();
        await DefinirEcheanceAsync(userId, fixture.Clock.UtcNow.AddDays(30));

        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneAsync(userId, TestContext.Current.CancellationToken))
            .ShouldBeTrue();
    }

    [Fact]
    public async Task Une_echeance_passee_redevient_gratuite_sans_intervention()
    {
        var userId = await fixture.CreerCompteAsync();
        await DefinirEcheanceAsync(userId, fixture.Clock.UtcNow.AddSeconds(-1));

        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneAsync(userId, TestContext.Current.CancellationToken))
            .ShouldBeFalse();
    }

    [Fact]
    public async Task Un_identifiant_inconnu_vaut_non_abonne()
    {
        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneAsync(Guid.CreateVersion7(), TestContext.Current.CancellationToken))
            .ShouldBeFalse();
    }

    [Fact]
    public async Task La_lecture_groupee_rend_une_entree_par_compte_connu()
    {
        var abonne = await fixture.CreerCompteAsync();
        var gratuit = await fixture.CreerCompteAsync();
        var inconnu = Guid.CreateVersion7();
        await DefinirEcheanceAsync(abonne, fixture.Clock.UtcNow.AddDays(1));

        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        var resultat = await formule.EstAbonneManyAsync(
            [abonne, gratuit, inconnu],
            TestContext.Current.CancellationToken);

        resultat[abonne].ShouldBeTrue();
        resultat[gratuit].ShouldBeFalse();
        resultat.ContainsKey(inconnu).ShouldBeFalse();
    }

    [Fact]
    public async Task La_lecture_groupee_d_une_liste_vide_ne_touche_pas_la_base()
    {
        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneManyAsync([], TestContext.Current.CancellationToken))
            .ShouldBeEmpty();
    }

    private async Task DefinirEcheanceAsync(Guid userId, DateTimeOffset echeance)
    {
        using var portee = fixture.Services.CreateScope();
        var db = portee.ServiceProvider.GetRequiredService<IUsersDbContext>();
        var compte = await db.Users.FirstAsync(
            u => u.Id == userId,
            TestContext.Current.CancellationToken);
        compte.PremiumUntil = echeance;
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);
    }
}
```

> **Avant d'écrire ce fichier** : ouvrir `api/tests/PartyPlan.IntegrationTests/Infrastructure/`
> et vérifier les noms réels de l'aide de création de compte et de l'horloge de test. Le
> dépôt en possède déjà — `CompteEtAdministrationTests.cs` en montre l'usage. Si les noms
> diffèrent de `fixture.CreerCompteAsync()` et `fixture.Clock`, **utiliser ceux du dépôt**
> plutôt que d'en ajouter. N'ajouter une aide que si aucune n'existe.

- [ ] **Étape 2 : exécuter le test et constater l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~FormuleCompteTests
```

Attendu : échec de compilation — `IFormuleCompte` n'existe pas.

- [ ] **Étape 3 : écrire le contrat**

`api/src/PartyPlan.SharedKernel/Contracts/IFormuleCompte.cs` :

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Formule d'un compte, telle que les autres modules ont besoin de la connaître.
/// <para>
/// Réduite à un booléen à dessein : un module applique un quota, il n'a pas à connaître
/// une échéance, un moyen de paiement ni un cycle de vie. Le lot 4.1 remplacera la
/// colonne <c>premium_until</c> par une table d'abonnements (ADR 0008) sans que ce
/// contrat change de forme, donc sans toucher à ses appelants.
/// </para>
/// </summary>
public interface IFormuleCompte
{
    /// <summary>Vrai si la formule payante est active à cet instant.</summary>
    Task<bool> EstAbonneAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// Formules de plusieurs comptes, en une requête.
    /// <para>
    /// Nécessaire pour la liste des événements : un appel par ligne referait autant de
    /// requêtes que de soirées, et le coût suivrait la taille de l'historique. Les
    /// identifiants inconnus sont absents du résultat, ce qui vaut « non abonné ».
    /// </para>
    /// </summary>
    Task<IReadOnlyDictionary<Guid, bool>> EstAbonneManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
```

- [ ] **Étape 4 : écrire l'implémentation**

`api/src/PartyPlan.Modules.Users/Application/FormuleCompte.cs` :

```csharp
namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Lit la formule sur <c>users.premium_until</c>. Un compte supprimé est traité comme
/// absent : sa formule n'a plus d'objet, et le laisser abonné ferait franchir un quota
/// à un compte anonymisé.
/// </summary>
public sealed class FormuleCompte(IUsersDbContext db, IClock clock) : IFormuleCompte
{
    public async Task<bool> EstAbonneAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        return await db.Users
            .AsNoTracking()
            .AnyAsync(
                u => u.Id == userId
                    && u.DeletedAt == null
                    && u.PremiumUntil != null
                    && u.PremiumUntil > maintenant,
                cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<IReadOnlyDictionary<Guid, bool>> EstAbonneManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(userIds);

        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, bool>();
        }

        var maintenant = clock.UtcNow;

        var comptes = await db.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id) && u.DeletedAt == null)
            .Select(u => new { u.Id, u.PremiumUntil })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return comptes.ToDictionary(
            c => c.Id,
            c => c.PremiumUntil != null && c.PremiumUntil > maintenant);
    }
}
```

- [ ] **Étape 5 : enregistrer le service**

Dans `api/src/PartyPlan.Modules.Users/UsersModule.cs`, méthode `AddServices`, à la suite
de la ligne `services.AddScoped<IUserIdentityLookup, UserIdentityLookup>();` :

```csharp
        // Contrat public consommé par Events pour appliquer les quotas (ADR 0008).
        services.AddScoped<IFormuleCompte, FormuleCompte>();
```

- [ ] **Étape 6 : exécuter les tests et constater le succès**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~FormuleCompteTests
```

Attendu : 6 tests verts.

- [ ] **Étape 7 : vérifier la frontière et le format**

```bash
cd api && dotnet format --verify-no-changes && cd .. && ./tools/verifier-frontieres-modules.sh
```

Attendu : aucune sortie d'erreur, code de retour 0.

- [ ] **Étape 8 : commit**

```bash
git add api/src/PartyPlan.SharedKernel/Contracts/IFormuleCompte.cs \
        api/src/PartyPlan.Modules.Users/Application/FormuleCompte.cs \
        api/src/PartyPlan.Modules.Users/UsersModule.cs \
        api/tests/PartyPlan.IntegrationTests/FormuleCompteTests.cs
git commit -m "feat(premium): IFormuleCompte, la frontière entre un quota et un abonnement

Le module Events doit savoir si un compte est abonné pour appliquer un
quota ; la règle 6 lui interdit la table users. Le contrat ne renvoie
qu'un booléen : le lot 4.1 remplacera la colonne par une table sans que
ses appelants changent.

Une échéance passée redevient gratuite sans intervention, et un compte
supprimé n'est jamais abonné — sinon un compte anonymisé franchirait
encore un quota."
```

---

### Tâche 2 : `QuotaEvenements`, l'unité qui décide

**Fichiers**
- Créer : `api/src/PartyPlan.Modules.Events/Application/QuotaEvenements.cs`
- Test : `api/tests/PartyPlan.UnitTests/QuotaEvenementsTests.cs`

**Interfaces**
- Consomme : `IFormuleCompte` (tâche 1), `IEventsDbContext`, `IClock`, `Event.IsPast`
  (`Domain/Event.cs:54`), `EventMemberRole.Owner` (`SharedKernel/Enums`).
- Produit : les constantes `QuotaEvenements.EvenementsMaximum = 3` et
  `MembresMaximum = 20` ; les erreurs statiques `QuotaEvenements.QuotaAtteint` et
  `PlafondMembresAtteint` ; les décisions pures
  `QuotaEvenements.CreationAutorisee(int possedes, bool abonne) → bool` et
  `AdhesionAutorisee(int membresActifs, bool proprietaireAbonne) → bool` ; les lectures
  `CompterPossedesAsync(Guid userId, CancellationToken) → Task<int>`,
  `CompterMembresActifsAsync(Guid eventId, CancellationToken) → Task<int>` et
  `ProprietaireAbonneAsync(Guid eventId, CancellationToken) → Task<bool>`. Consommés par
  les tâches 3 et 4.

- [ ] **Étape 1 : écrire le test unitaire qui échoue**

`api/tests/PartyPlan.UnitTests/QuotaEvenementsTests.cs` :

```csharp
namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Décisions de quota de la formule gratuite (RG-PRM-01, ADR 0008).
/// <para>
/// Les frontières exactes sont testées parce qu'un quota mal borné ouvre ou ferme le
/// produit à tort : à 2 on doit pouvoir créer, à 3 non, et un abonné ne rencontre
/// jamais la borne.
/// </para>
/// </summary>
public sealed class QuotaEvenementsTests
{
    [Theory]
    [InlineData(0, true)]
    [InlineData(1, true)]
    [InlineData(2, true)]
    [InlineData(3, false)]
    [InlineData(4, false)]
    public void La_creation_est_bornee_a_trois_evenements_possedes(int possedes, bool attendu)
    {
        QuotaEvenements.CreationAutorisee(possedes, abonne: false).ShouldBe(attendu);
    }

    [Theory]
    [InlineData(3)]
    [InlineData(10)]
    [InlineData(100)]
    public void Un_abonne_ne_rencontre_jamais_la_borne_de_creation(int possedes)
    {
        QuotaEvenements.CreationAutorisee(possedes, abonne: true).ShouldBeTrue();
    }

    [Theory]
    [InlineData(0, true)]
    [InlineData(18, true)]
    [InlineData(19, true)]
    [InlineData(20, false)]
    [InlineData(21, false)]
    public void L_adhesion_est_bornee_a_vingt_membres_actifs(int membres, bool attendu)
    {
        QuotaEvenements.AdhesionAutorisee(membres, proprietaireAbonne: false).ShouldBe(attendu);
    }

    [Theory]
    [InlineData(20)]
    [InlineData(50)]
    public void Le_plafond_de_membres_est_leve_par_la_formule_du_proprietaire(int membres)
    {
        // EF-PRM-03 : la formule du propriétaire bénéficie à tous les membres. C'est
        // la sienne qui compte, jamais celle de l'arrivant.
        QuotaEvenements.AdhesionAutorisee(membres, proprietaireAbonne: true).ShouldBeTrue();
    }

    [Fact]
    public void Les_quotas_annonces_sont_ceux_du_cahier_des_charges()
    {
        QuotaEvenements.EvenementsMaximum.ShouldBe(3);
        QuotaEvenements.MembresMaximum.ShouldBe(20);
    }

    [Fact]
    public void Les_deux_refus_sont_des_interdictions_et_nomment_leur_sortie()
    {
        QuotaEvenements.QuotaAtteint.Code.ShouldBe("plan.event_quota_reached");
        QuotaEvenements.QuotaAtteint.Kind.ShouldBe(ErrorKind.Forbidden);
        QuotaEvenements.QuotaAtteint.Message.ShouldContain("3");

        QuotaEvenements.PlafondMembresAtteint.Code.ShouldBe("plan.member_limit_reached");
        QuotaEvenements.PlafondMembresAtteint.Kind.ShouldBe(ErrorKind.Forbidden);
        QuotaEvenements.PlafondMembresAtteint.Message.ShouldContain("20");
    }
}
```

Ajouter en tête du fichier, avec les autres `using` : `using PartyPlan.SharedKernel.Primitives;`
(pour `ErrorKind`).

- [ ] **Étape 2 : exécuter et constater l'échec**

```bash
cd api && dotnet test tests/PartyPlan.UnitTests --filter FullyQualifiedName~QuotaEvenementsTests
```

Attendu : échec de compilation — `QuotaEvenements` n'existe pas.

- [ ] **Étape 3 : écrire l'unité**

`api/src/PartyPlan.Modules.Events/Application/QuotaEvenements.cs` :

```csharp
namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Quotas de la formule gratuite (RG-PRM-01, ADR 0008).
/// <para>
/// Les décisions sont des méthodes statiques pures, séparées des lectures : les
/// frontières exactes se testent alors sans base ni horloge. Les deux règles partagent
/// la lecture de la formule, d'où une unité unique plutôt que deux méthodes dispersées
/// dans EventService et JoinService.
/// </para>
/// <para>
/// Ces quotas bornent une offre commerciale. Ils ne protègent ni un cloisonnement ni un
/// calcul financier, et aucune garantie transactionnelle n'est tentée : deux écritures
/// concurrentes au bord de la borne peuvent la franchir d'une unité, ce que RG-PRM-02
/// rend inoffensif puisque rien n'est jamais dégradé après coup.
/// </para>
/// </summary>
public sealed class QuotaEvenements(
    IEventsDbContext db,
    IFormuleCompte formule,
    IClock clock)
{
    /// <summary>Événements possédés simultanément en formule gratuite.</summary>
    public const int EvenementsMaximum = 3;

    /// <summary>Membres actifs par événement en formule gratuite.</summary>
    public const int MembresMaximum = 20;

    public static readonly DomainError QuotaAtteint = DomainError.Forbidden(
        "plan.event_quota_reached",
        $"Tu organises déjà {EvenementsMaximum} soirées à venir, le maximum de la formule "
        + "gratuite. Attends la fin de l'une d'elles, quitte-la ou supprime-la — ou passe "
        + "à la formule payante.");

    public static readonly DomainError PlafondMembresAtteint = DomainError.Forbidden(
        "plan.member_limit_reached",
        $"Cette soirée a atteint {MembresMaximum} participants, le maximum de la formule "
        + "gratuite de son organisateur.");

    /// <summary>Décision de création. Pure : testable sans base.</summary>
    public static bool CreationAutorisee(int possedes, bool abonne) =>
        abonne || possedes < EvenementsMaximum;

    /// <summary>Décision d'adhésion. La formule est celle du propriétaire (EF-PRM-03).</summary>
    public static bool AdhesionAutorisee(int membresActifs, bool proprietaireAbonne) =>
        proprietaireAbonne || membresActifs < MembresMaximum;

    /// <summary>
    /// Événements possédés et encore actifs.
    /// <para>
    /// La propriété se lit sur <c>event_members.role</c> et non sur
    /// <c>events.created_by_user_id</c> : le premier suit les transferts
    /// (AttendanceService.TransfererProprieteAsync), le second reste au créateur
    /// historique. Compter le créateur débiterait le cédant d'un événement qu'il ne
    /// possède plus et n'en créditerait jamais le repreneur.
    /// </para>
    /// <para>
    /// La fin effective est évaluée en mémoire : elle dépend de <c>EffectiveEndsAt</c>
    /// (Event.cs:52), propriété calculée qu'EF Core ne traduit pas en SQL. Le volume est
    /// borné par le nombre d'événements d'une personne, comme dans ListerAsync.
    /// </para>
    /// </summary>
    public async Task<int> CompterPossedesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var bornes = await db.Events
            .AsNoTracking()
            .Where(e => e.DeletedAt == null
                && e.Members.Any(m =>
                    m.UserId == userId
                    && m.Role == EventMemberRole.Owner
                    && m.RemovedAt == null))
            .Select(e => new { e.StartsAt, e.EndsAt })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return bornes.Count(b => (b.EndsAt ?? b.StartsAt + Event.ImplicitDuration) > maintenant);
    }

    /// <summary>Membres actifs d'un événement. Les accompagnants n'y entrent pas (RG-PRES-04).</summary>
    public Task<int> CompterMembresActifsAsync(Guid eventId, CancellationToken cancellationToken) =>
        db.EventMembers
            .AsNoTracking()
            .CountAsync(m => m.EventId == eventId && m.RemovedAt == null, cancellationToken);

    /// <summary>
    /// Formule du propriétaire de l'événement. Sans propriétaire identifiable — ligne
    /// historique sans compte — la formule est gratuite : mieux vaut refuser une
    /// vingt-et-unième adhésion que lever un plafond sur une donnée absente.
    /// </summary>
    public async Task<bool> ProprietaireAbonneAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var proprietaire = await db.EventMembers
            .AsNoTracking()
            .Where(m => m.EventId == eventId
                && m.Role == EventMemberRole.Owner
                && m.RemovedAt == null
                && m.UserId != null)
            .Select(m => m.UserId)
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        return proprietaire is { } userId
            && await formule.EstAbonneAsync(userId, cancellationToken).ConfigureAwait(false);
    }
}
```

> **Vérifié le 28/08/2026** : `Event.ImplicitDuration` est `public static readonly`
> (`Domain/Event.cs:9`), donc directement utilisable. Ne pas dupliquer la valeur de
> 12 heures dans `QuotaEvenements` — deux sources pour une même règle finissent par
> diverger. Le filtrage reste en mémoire : `static readonly` n'est pas une constante
> compilée, et la fin effective dépend d'un calcul qu'EF Core ne traduit pas.

- [ ] **Étape 4 : enregistrer le service**

Dans `api/src/PartyPlan.Modules.Events/EventsModule.cs`, méthode `AddServices` :

```csharp
        services.AddScoped<QuotaEvenements>();
```

- [ ] **Étape 5 : exécuter et constater le succès**

```bash
cd api && dotnet test tests/PartyPlan.UnitTests --filter FullyQualifiedName~QuotaEvenementsTests
```

Attendu : tous verts (17 cas).

- [ ] **Étape 6 : commit**

```bash
git add api/src/PartyPlan.Modules.Events/Application/QuotaEvenements.cs \
        api/src/PartyPlan.Modules.Events/EventsModule.cs \
        api/tests/PartyPlan.UnitTests/QuotaEvenementsTests.cs
git commit -m "feat(premium): QuotaEvenements, décisions pures et lectures séparées

Les frontières exactes — 2/3/4 événements, 19/20/21 membres — se testent
sans base parce que la décision est une méthode statique et la lecture un
appel distinct.

La propriété se lit sur event_members.role et non sur
events.created_by_user_id : le premier suit les transferts, le second
reste au créateur historique. Compter le créateur débiterait le cédant
d'un événement qu'il ne possède plus."
```

---

### Tâche 3 : le quota à la création d'un événement

**Fichiers**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/EventService.cs` (constructeur,
  et `CreateAsync` autour de la ligne 92)
- Test : `api/tests/PartyPlan.IntegrationTests/QuotaEvenementsApiTests.cs`

**Interfaces**
- Consomme : `QuotaEvenements.CompterPossedesAsync`, `QuotaEvenements.CreationAutorisee`,
  `QuotaEvenements.QuotaAtteint`, `IFormuleCompte.EstAbonneAsync` (tâches 1 et 2).
- Produit : `POST /v1/events` renvoie 403 `plan.event_quota_reached` au-delà du quota.

- [ ] **Étape 1 : écrire les tests d'intégration qui échouent**

`api/tests/PartyPlan.IntegrationTests/QuotaEvenementsApiTests.cs` — couvrir, un `[Fact]`
par ligne :

1. `Trois_creations_passent_la_quatrieme_est_refusee` : créer 3 événements à venir, la 4ᵉ
   renvoie 403 et le corps RFC 9457 porte `plan.event_quota_reached`.
2. `Une_soiree_terminee_rend_sa_place_sans_rien_supprimer` : créer 3 événements dont un
   dont la fin est passée (avancer `fixture.Clock`, ou créer avec `startsAt` et `endsAt`
   passés) ; la 4ᵉ création réussit, et l'événement terminé reste lisible en 200.
3. `Supprimer_une_soiree_rend_sa_place` : 3 événements, en supprimer un, la création
   réussit.
4. `Un_abonne_depasse_le_quota` : rendre le compte abonné (échéance future en base), créer
   6 événements, tous en 201.
5. `Etre_membre_sans_posseder_ne_consomme_rien` : le compte A crée 3 événements et invite
   B ; B rejoint les 3 puis crée ses propres 3 événements, tous en 201.
6. `Un_transfert_libere_la_place_du_cedant_et_la_prend_chez_le_repreneur` : A possède 3,
   transfère un événement à B, puis A crée un 4ᵉ avec succès.
7. `Au_dela_du_quota_apres_transfert_tout_reste_utilisable` : amener B à 4 possédés par
   transferts ; ses 4 événements répondent 200 en lecture et acceptent une modification
   (`RG-PRM-02`, `RG-PRM-03`) ; seule une nouvelle création renvoie 403.

Modèle de premier test, à décliner :

```csharp
    [Fact]
    public async Task Trois_creations_passent_la_quatrieme_est_refusee()
    {
        var jeton = await fixture.ConnecterNouveauCompteAsync();

        for (var i = 1; i <= QuotaEvenements.EvenementsMaximum; i++)
        {
            var ok = await CreerAsync(jeton, $"Soirée {i}");
            ok.StatusCode.ShouldBe(HttpStatusCode.Created);
        }

        var refus = await CreerAsync(jeton, "Soirée de trop");

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        var probleme = await refus.Content.ReadFromJsonAsync<JsonElement>(
            TestContext.Current.CancellationToken);
        probleme.GetProperty("type").GetString().ShouldContain("plan.event_quota_reached");
    }
```

> Reprendre le nom exact du champ portant le code d'erreur en lisant un test existant qui
> assert une erreur RFC 9457 — voir `EvenementsTests.cs`. Ne pas deviner entre `type`,
> `code` et `detail`.

- [ ] **Étape 2 : exécuter et constater l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~QuotaEvenementsApiTests
```

Attendu : le test 1 échoue — la 4ᵉ création renvoie 201 au lieu de 403.

- [ ] **Étape 3 : injecter le quota dans `EventService`**

Ajouter `QuotaEvenements quota` et `IFormuleCompte formule` à la liste des paramètres du
constructeur principal de `EventService`.

- [ ] **Étape 4 : appliquer le quota dans `CreateAsync`**

Dans `CreateAsync`, **après** la validation de la requête et **avant** le tirage du code
court — inutile de consommer une tentative de code court pour une création qui sera
refusée :

```csharp
        var abonne = await formule.EstAbonneAsync(utilisateur, cancellationToken)
            .ConfigureAwait(false);

        if (!abonne)
        {
            var possedes = await quota.CompterPossedesAsync(utilisateur, cancellationToken)
                .ConfigureAwait(false);

            if (!QuotaEvenements.CreationAutorisee(possedes, abonne))
            {
                return QuotaEvenements.QuotaAtteint;
            }
        }
```

Le comptage est évité pour un abonné : sa formule lève la borne, la requête serait inutile.

- [ ] **Étape 5 : exécuter et constater le succès**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~QuotaEvenementsApiTests
```

Attendu : les 7 tests verts.

- [ ] **Étape 6 : non-régression sur les événements**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~EvenementsTests
```

Attendu : vert. Un test existant qui créerait plus de 3 événements avec le même compte
devient rouge — c'est un vrai signal, pas un faux positif : le corriger en répartissant les
créations sur plusieurs comptes, jamais en relevant le quota.

- [ ] **Étape 7 : commit**

```bash
git add api/src/PartyPlan.Modules.Events/Application/EventService.cs \
        api/tests/PartyPlan.IntegrationTests/QuotaEvenementsApiTests.cs
git commit -m "feat(premium): plafonner la création à trois soirées possédées

Le quota est vérifié avant le tirage du code court : inutile d'en
consommer une tentative pour une création refusée. Il n'est pas compté du
tout pour un abonné, dont la formule lève la borne.

Une soirée terminée libère sa place d'elle-même — c'est le renversement
de la conception du 25/08, qui exigeait une suppression et donc la
destruction des dépenses et des remboursements de la soirée effacée."
```

---

### Tâche 4 : le plafond de membres à l'adhésion, et « complet » sur l'aperçu

**Fichiers**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/JoinService.cs` (constructeur,
  `JoinPreview` ligne 19, `RejoindreAsync` ligne 107, `ApercuAsync` ligne 192)
- Test : `api/tests/PartyPlan.IntegrationTests/PlafondMembresTests.cs`

**Interfaces**
- Consomme : `QuotaEvenements.CompterMembresActifsAsync`,
  `QuotaEvenements.ProprietaireAbonneAsync`, `QuotaEvenements.AdhesionAutorisee`,
  `QuotaEvenements.PlafondMembresAtteint` (tâche 2).
- Produit : `JoinPreview` gagne un champ final `bool Complet` ; les deux endpoints
  d'adhésion renvoient 403 `plan.member_limit_reached` au plafond.

- [ ] **Étape 1 : écrire les tests d'intégration qui échouent**

`api/tests/PartyPlan.IntegrationTests/PlafondMembresTests.cs` — un `[Fact]` par ligne :

1. `La_vingt_et_unieme_adhesion_est_refusee` : amener l'événement à 20 membres actifs
   (l'organisateur compte pour un, donc 19 adhésions), la 21ᵉ renvoie 403
   `plan.member_limit_reached`.
2. `Un_membre_deja_present_rejoue_son_adhesion_a_vingt_sur_vingt` : à 20/20, un membre
   existant rappelle l'endpoint et reçoit un succès — `RG-INV-05` passe avant le quota.
3. `Le_plafond_suit_le_proprietaire_pas_l_arrivant` : propriétaire abonné, événement à
   20 membres, un arrivant gratuit entre en succès ; puis propriétaire gratuit et arrivant
   abonné, l'adhésion est refusée.
4. `Les_accompagnants_ne_consomment_aucune_place` : 19 membres dont un déclare 10
   accompagnants ; une 20ᵉ adhésion réussit.
5. `Un_membre_exclu_libere_sa_place` : à 20/20, exclure un membre, l'adhésion suivante
   réussit.
6. `L_apercu_public_annonce_complet` : à 20/20, `GET` de l'aperçu par jeton et par code
   court renvoie `complet: true` ; en dessous, `false`.
7. `Un_evenement_d_abonne_n_est_jamais_complet` : propriétaire abonné, 25 membres,
   l'aperçu renvoie `complet: false`.

- [ ] **Étape 2 : exécuter et constater l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~PlafondMembresTests
```

Attendu : échec — la 21ᵉ adhésion réussit, et `complet` n'existe pas dans la réponse.

- [ ] **Étape 3 : ajouter `Complet` à l'aperçu**

`JoinService.cs`, record `JoinPreview` — ajouter le champ **en dernière position** pour ne
casser aucun appel positionnel existant :

```csharp
public sealed record JoinPreview(
    string Name,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    string? Address,
    string? Description,
    int ParticipantCount,
    bool JoinEnabled,
    bool AlreadyMember,
    bool Complet);
```

- [ ] **Étape 4 : injecter le quota et renseigner `Complet`**

Ajouter `QuotaEvenements quota` aux paramètres du constructeur de `JoinService`.

Dans `ApercuAsync`, après le calcul de `participants` :

```csharp
        // Annoncé avant toute création de compte : sans cela, un invité s'inscrirait
        // pour découvrir ensuite qu'il ne peut pas entrer (RG-INV-04 autorise déjà le
        // nombre de participants, aucune donnée nouvelle n'est exposée).
        var proprietaireAbonne = await quota
            .ProprietaireAbonneAsync(evenement.Id, cancellationToken)
            .ConfigureAwait(false);

        var complet = !QuotaEvenements.AdhesionAutorisee(participants, proprietaireAbonne);
```

et passer `complet` en dernier argument du `new JoinPreview(...)`.

- [ ] **Étape 5 : appliquer le plafond à l'adhésion**

Dans la surcharge privée `RejoindreAsync`, **après** le bloc `if (existant is not null)` —
donc après l'idempotence de `RG-INV-05` — et **après** le contrôle `JoinEnabled` :

```csharp
        var proprietaireAbonne = await quota
            .ProprietaireAbonneAsync(evenement.Id, cancellationToken)
            .ConfigureAwait(false);

        if (!proprietaireAbonne)
        {
            var membresActifs = await quota
                .CompterMembresActifsAsync(evenement.Id, cancellationToken)
                .ConfigureAwait(false);

            if (!QuotaEvenements.AdhesionAutorisee(membresActifs, proprietaireAbonne))
            {
                return QuotaEvenements.PlafondMembresAtteint;
            }
        }
```

L'ordre est la règle, pas un détail : vérifier le quota avant l'idempotence ferait échouer
un rejeu légitime à 20/20, et un simple doublon de requête réseau suffirait à refuser une
adhésion déjà acquise.

- [ ] **Étape 6 : exécuter et constater le succès**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~PlafondMembresTests
```

Attendu : les 7 tests verts.

- [ ] **Étape 7 : régénérer le contrat OpenAPI**

`JoinPreview` a changé de forme, et `docs/api/openapi.json` est versionné.

```bash
make up          # si la pile n'est pas déjà démarrée
curl -s http://localhost:5080/openapi/v1.json -o docs/api/openapi.json
git diff --stat docs/api/openapi.json
```

Attendu : le diff ne montre que l'ajout de `complet`. S'il montre autre chose, s'arrêter et
comprendre pourquoi avant de commiter.

- [ ] **Étape 8 : non-régression sur les invitations**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~Invitation
```

Attendu : vert.

- [ ] **Étape 9 : commit**

```bash
git add api/src/PartyPlan.Modules.Events/Application/JoinService.cs \
        api/tests/PartyPlan.IntegrationTests/PlafondMembresTests.cs \
        docs/api/openapi.json
git commit -m "feat(premium): plafonner une soirée à vingt participants

Le plafond est celui du propriétaire, jamais celui de l'arrivant : c'est
EF-PRM-03 appliqué à l'adhésion. Rejoindre reste illimité en formule
gratuite, sans quoi une invitation échouerait pour un motif étranger à
l'événement comme à son organisateur.

L'idempotence de RG-INV-05 est vérifiée avant le quota : un rejeu à 20/20
doit réussir, sinon un doublon de requête refuserait une adhésion déjà
acquise.

L'aperçu public annonce « complet » pour qu'un invité ne crée pas un
compte avant de découvrir qu'il ne peut pas entrer."
```

---

### Tâche 5 : attribution de la formule par un administrateur

**Fichiers**
- Créer : `api/src/PartyPlan.Modules.Users/Application/PlanAdminService.cs`
- Créer : `api/src/PartyPlan.Modules.Users/Endpoints/AdminPlanEndpoints.cs`
- Modifier : `api/src/PartyPlan.SharedKernel/Contracts/AdminAuditActions.cs`
- Modifier : `api/src/PartyPlan.Modules.Users/UsersModule.cs` (`AddServices`, `MapEndpoints`)
- Test : `api/tests/PartyPlan.IntegrationTests/AttributionFormuleTests.cs`

**Interfaces**
- Consomme : `IUsersDbContext`, `IClock`, `IAuditLog.RecordAsync`
  (`SharedKernel/Contracts/IAuditLog.cs`), la politique d'autorisation `PlatformAdmin`
  existante.
- Produit : `PUT /v1/admin/users/{userId}/plan` et `DELETE /v1/admin/users/{userId}/plan`,
  204 tous deux ; la constante `AdminAuditActions.PlanChanged = "user.plan_changed"`.

- [ ] **Étape 1 : écrire les tests d'intégration qui échouent**

`api/tests/PartyPlan.IntegrationTests/AttributionFormuleTests.cs` — un `[Fact]` par ligne :

1. `Un_administrateur_accorde_puis_retire_la_formule` : `PUT` avec échéance future et motif
   → 204, `GET /v1/me` du compte cible montre `premiumUntil` ; `DELETE` avec motif → 204,
   `premiumUntil` redevient nul.
2. `Le_role_support_est_refuse` : `Support` reçoit 403 sur `PUT` et sur `DELETE`
   (`RG-ADM-05`).
3. `Un_compte_ordinaire_est_refuse` : `User` reçoit 403 sur les deux.
4. `Une_echeance_passee_est_refusee` : `PUT` avec une échéance antérieure à maintenant →
   400, code `plan.expiry_in_past`.
5. `Une_echeance_absente_est_refusee` : `PUT` sans `premiumUntil` → 400, code
   `plan.expiry_required`.
6. `Un_motif_absent_est_refuse` : `PUT` et `DELETE` sans motif → 400, code
   `plan.reason_required`.
7. `Un_compte_inconnu_renvoie_introuvable` : `PUT` sur un identifiant inexistant → 404.
8. `Chaque_changement_effectif_ecrit_une_ligne_d_audit` : après `PUT` puis `DELETE`, le
   journal d'audit contient deux entrées `user.plan_changed` portant l'ancienne et la
   nouvelle échéance.
9. `Reappliquer_la_meme_echeance_n_ecrit_pas_d_audit` : deux `PUT` identiques → 204 les
   deux fois, une seule entrée d'audit.
10. `La_ligne_d_audit_resiste_a_la_modification` : suivre le motif de
    `AppendOnlyTablesTests.cs` pour vérifier qu'`UPDATE` et `DELETE` échouent sur l'entrée
    (`NF-SEC-08`).

- [ ] **Étape 2 : exécuter et constater l'échec**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~AttributionFormuleTests
```

Attendu : 404 sur toutes les routes — elles n'existent pas.

- [ ] **Étape 3 : ajouter l'action d'audit**

Dans `api/src/PartyPlan.SharedKernel/Contracts/AdminAuditActions.cs`, à la suite de
`AvatarRemoved` :

```csharp
    /// <summary>
    /// Changement de formule (EF-PRM-04). Une seule action pour l'octroi et le retrait :
    /// c'est le même geste, et la nouvelle échéance distingue l'un de l'autre. Deux
    /// constantes auraient obligé chaque lecteur du journal à savoir laquelle chercher.
    /// </summary>
    public const string PlanChanged = "user.plan_changed";
```

- [ ] **Étape 4 : écrire le service**

`api/src/PartyPlan.Modules.Users/Application/PlanAdminService.cs` :

```csharp
namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Attribution de la formule payante par un administrateur (EF-PRM-04).
/// <para>
/// Seul moyen d'attribution jusqu'au lot 4.1 : aucun encaissement n'existe. Réservé au
/// PlatformAdmin — RG-ADM-05 borne le rôle Support à la consultation et au dépannage, et
/// offrir un abonnement n'est ni l'un ni l'autre.
/// </para>
/// </summary>
public sealed class PlanAdminService(IUsersDbContext db, IClock clock, IAuditLog audit)
{
    public static readonly DomainError EcheanceRequise = DomainError.Validation(
        "plan.expiry_required",
        "Indique une échéance : une formule payante sans terme ne se renouvelle pas.");

    public static readonly DomainError EcheanceDansLePasse = DomainError.Validation(
        "plan.expiry_in_past",
        "L'échéance doit être dans le futur.");

    public static readonly DomainError MotifRequis = DomainError.Validation(
        "plan.reason_required",
        "Indique un motif : le journal d'audit doit dire pourquoi.");

    public static readonly DomainError CompteIntrouvable = DomainError.NotFound(
        "user.not_found",
        "Ce compte est introuvable.");

    public async Task<Result> AccorderAsync(
        Guid userId,
        DateTimeOffset? echeance,
        string? motif,
        CancellationToken cancellationToken)
    {
        if (echeance is not { } terme)
        {
            return EcheanceRequise;
        }

        if (terme <= clock.UtcNow)
        {
            return EcheanceDansLePasse;
        }

        return await AppliquerAsync(userId, terme, motif, cancellationToken).ConfigureAwait(false);
    }

    public Task<Result> RetirerAsync(Guid userId, string? motif, CancellationToken cancellationToken) =>
        AppliquerAsync(userId, null, motif, cancellationToken);

    private async Task<Result> AppliquerAsync(
        Guid userId,
        DateTimeOffset? echeance,
        string? motif,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(motif))
        {
            return MotifRequis;
        }

        var compte = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (compte is null)
        {
            return CompteIntrouvable;
        }

        var precedente = compte.PremiumUntil;

        // Rien à écrire si rien ne change : le back-office se manipule à la main, et un
        // double clic produirait deux lignes identiques dans un journal inaltérable.
        if (precedente == echeance)
        {
            return Result.Success();
        }

        compte.PremiumUntil = echeance;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await audit
            .RecordAsync(
                AdminAuditActions.PlanChanged,
                userId,
                motif.Trim(),
                new { precedente, nouvelle = echeance },
                cancellationToken)
            .ConfigureAwait(false);

        return Result.Success();
    }
}
```

- [ ] **Étape 5 : écrire les endpoints**

`api/src/PartyPlan.Modules.Users/Endpoints/AdminPlanEndpoints.cs` — calquer la structure,
les noms de politique d'autorisation et la traduction des `Result` sur un fichier
d'endpoints d'administration existant. **Lire d'abord** les endpoints qui portent la
suspension ou le changement de rôle : ils sont déjà réservés au `PlatformAdmin`, et c'est
la même politique qu'il faut réutiliser, pas une nouvelle.

Corps des requêtes :

```csharp
public sealed record AccorderFormuleRequest(DateTimeOffset? PremiumUntil, string? Reason);

public sealed record RetirerFormuleRequest(string? Reason);
```

Routes : `PUT /v1/admin/users/{userId:guid}/plan` et
`DELETE /v1/admin/users/{userId:guid}/plan`, réponses 204.

- [ ] **Étape 6 : enregistrer service et endpoints**

Dans `UsersModule.AddServices` : `services.AddScoped<PlanAdminService>();`
Dans `UsersModule.MapEndpoints` : `AdminPlanEndpoints.Map(routes);`

- [ ] **Étape 7 : exécuter et constater le succès**

```bash
cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FullyQualifiedName~AttributionFormuleTests
```

Attendu : les 10 tests verts.

- [ ] **Étape 8 : régénérer le contrat OpenAPI**

```bash
curl -s http://localhost:5080/openapi/v1.json -o docs/api/openapi.json
```

- [ ] **Étape 9 : commit**

```bash
git add api/src/PartyPlan.Modules.Users/Application/PlanAdminService.cs \
        api/src/PartyPlan.Modules.Users/Endpoints/AdminPlanEndpoints.cs \
        api/src/PartyPlan.SharedKernel/Contracts/AdminAuditActions.cs \
        api/src/PartyPlan.Modules.Users/UsersModule.cs \
        api/tests/PartyPlan.IntegrationTests/AttributionFormuleTests.cs \
        docs/api/openapi.json
git commit -m "feat(premium): attribuer la formule payante depuis le back-office

Seul moyen d'attribution jusqu'au lot 4.1, faute d'encaissement. Réservé
au PlatformAdmin : RG-ADM-05 borne le rôle Support à la consultation et au
dépannage, et offrir un abonnement n'est ni l'un ni l'autre.

Échéance obligatoire et dans le futur : une formule sans terme ne se
renouvelle pas, et la traduire par une date en 2099 se paierait au lot 4.1.

Une seule action d'audit pour l'octroi et le retrait — c'est le même
geste, la nouvelle échéance les distingue. Réappliquer la même échéance
n'écrit rien : un double clic ne doit pas laisser deux lignes identiques
dans un journal inaltérable."
```

---

### Tâche 6 : le quota et la formule dans l'application Flutter

**Fichiers**
- Modifier : le modèle de profil et son client d'API côté `app/lib/` — localiser avec
  `grep -rn "premiumUntil\|PremiumUntil" app/lib/` puis, si le champ n'est pas encore
  transporté, l'ajouter au modèle qui décode `GET /v1/me`.
- Créer : un composant de quota réutilisable dans le dossier des composants partagés du
  design system (`grep -rln "class Pp" app/lib/ | head` pour trouver la convention et le
  répertoire).
- Modifier : l'écran de profil, l'écran d'accueil, et l'écran de fiche compte du
  back-office.
- Test : `app/test/` — suivre l'organisation existante.

**Interfaces**
- Consomme : `premiumUntil` de `GET /v1/me` ; la liste des événements de `GET /v1/events`
  avec le rôle de l'appelant, déjà exposé par `EventListItem` (`Role`).
- Produit : un composant affichant la formule, et un affichage du quota consommé.

- [ ] **Étape 1 : localiser les points d'accroche**

```bash
grep -rn "premiumUntil" app/lib/ ; grep -rln "class Pp" app/lib/ | head -20
```

Noter les chemins réels avant d'écrire quoi que ce soit. Ne créer aucun composant dont
l'équivalent existe déjà.

- [ ] **Étape 2 : écrire les tests de widget qui échouent**

Trois tests, dans le style des tests de widget existants :

1. un profil sans échéance affiche « Gratuit » ;
2. un profil avec échéance au 28/09/2026 affiche « Premium jusqu'au 28/09/2026 » — format
   JJ/MM/AAAA vérifié dans l'assertion ;
3. l'accueil d'un compte gratuit possédant 2 événements à venir affiche « 2 soirées sur 3 »,
   et n'affiche rien pour un compte abonné.

- [ ] **Étape 3 : exécuter et constater l'échec**

```bash
cd app && flutter test
```

Attendu : échec sur les trois nouveaux tests.

- [ ] **Étape 4 : implémenter**

Contraintes non négociables, reprises de `CLAUDE.md` :
- jetons du design system pour couleurs, espacements, rayons et typographie — rien en dur ;
- composant réutilisable, pas de duplication entre profil, accueil et back-office ;
- états chargement, vide et erreur ;
- libellés sémantiques pour l'accessibilité, zones tactiles de 44 points ;
- chaînes dans le fichier de chaînes, aucune en dur dans un écran ;
- responsive mobile, tablette et web.

Le décompte affiché sur l'accueil se calcule à partir de la liste des événements déjà
chargée — rôle `Owner` et événement non passé. **Ne pas ajouter d'endpoint** pour ça : la
donnée est là, et une route de plus serait un aller-retour réseau pour un calcul de deux
lignes.

- [ ] **Étape 5 : exécuter et constater le succès**

```bash
cd app && flutter test && flutter analyze
```

Attendu : tests verts, analyse sans avertissement.

- [ ] **Étape 6 : vérifier dans l'application réelle**

Invoquer le skill `run`. Vérifier de visu : profil gratuit, profil abonné, accueil à 2/3,
refus de création à 3/3, et l'action du back-office. Le refus doit afficher le message du
serveur, pas un texte réécrit côté client.

- [ ] **Étape 7 : commit**

```bash
git add app/
git commit -m "feat(premium): afficher la formule et le quota consommé

Une limite qu'on ne découvre qu'au refus est une mauvaise surprise :
l'accueil annonce « 2 soirées sur 3 » avant que la création soit
refusée.

Le décompte se calcule sur la liste d'événements déjà chargée — le rôle
de l'appelant y figure. Un endpoint de plus aurait été un aller-retour
réseau pour deux lignes de calcul.

Pas d'écran Premium ni de bouton d'achat : aucun encaissement n'existe, et
le produit s'interdit déjà les boutons condamnés."
```

---

### Tâche 7 : vérification complète et feuille de route

**Fichiers**
- Modifier : `docs/roadmap.md` (lot 1.19)

- [ ] **Étape 1 : vérification complète**

```bash
make verif
```

Attendu : format, analyse, frontières et tests tous verts. **Coller la sortie** dans le
compte rendu — `superpowers:verification-before-completion` interdit d'annoncer un succès
sans elle.

- [ ] **Étape 2 : cocher le lot 1.19**

Cocher dans `docs/roadmap.md` les lignes effectivement livrées, et **seulement** celles-là.
Le préambule du document rappelle pourquoi : un suivi qui décrit un état faux est pire
qu'absent. Ajouter sous chaque ligne non cochée la raison de son report.

- [ ] **Étape 3 : commit**

```bash
git add docs/roadmap.md
git commit -m "docs(premium): acter le lot 1.19 livré"
```

- [ ] **Étape 4 : revue de code**

Invoquer `superpowers:requesting-code-review`. Le domaine touche deux modules, une
frontière et une règle d'autorisation : la revue n'est pas facultative.

---

## Auto-revue du plan

**Couverture de la spec** — §2 frontière → tâche 1 ; §3 quota d'événements → tâches 2 et 3 ;
§4 plafond de membres et aperçu → tâches 2 et 4 ; §5 attribution et audit → tâche 5 ;
§6 affichage → tâche 6 ; §7 unités → réparties ; §8 tests → dans chaque tâche ;
§10 ordre d'exécution → ordre des tâches. Aucune section sans tâche.

**Cohérence des types** — `EstAbonneAsync` / `EstAbonneManyAsync` (tâche 1) sont appelées
sous ces noms exacts aux tâches 2, 3 et 4. `CompterPossedesAsync`,
`CompterMembresActifsAsync`, `ProprietaireAbonneAsync`, `CreationAutorisee`,
`AdhesionAutorisee`, `QuotaAtteint`, `PlafondMembresAtteint` (tâche 2) sont reprises
identiquement aux tâches 3 et 4. `AdminAuditActions.PlanChanged` (tâche 5) est unique.

**Points laissés à vérifier dans le dépôt plutôt que devinés**, chacun signalé dans sa
tâche : les aides de la `fixture` de test, le nom du champ portant le code d'erreur RFC 9457,
la politique d'autorisation `PlatformAdmin`, et
les chemins réels côté Flutter. Deviner l'un de ces noms produirait du code qui ne compile
pas ou, pire, un second mécanisme là où le dépôt en a déjà un.
