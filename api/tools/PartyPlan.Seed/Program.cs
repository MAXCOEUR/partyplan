using Microsoft.EntityFrameworkCore;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.Modules.Shopping.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Enums;

// Jeu de données de démonstration pour le développement local (NF-DEV-07).
//
// Refuse de s'exécuter ailleurs qu'en développement : un jeu de données factices en
// production polluerait des données réelles (RG-DEV-01).

var environnement = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Development";

if (!string.Equals(environnement, "Development", StringComparison.OrdinalIgnoreCase))
{
    Console.Error.WriteLine(
        $"Refus : le jeu de démonstration ne s'installe qu'en Development (ici « {environnement} »). "
        + "Voir RG-DEV-01.");
    return 1;
}

var factory = new PartyPlanDbContextFactory();
await using var db = factory.CreateDbContext(args);

if (!await db.Database.CanConnectAsync())
{
    Console.Error.WriteLine("Base injoignable. Lancer « make up » ou « make api » d'abord.");
    return 1;
}

var enAttente = await db.Database.GetPendingMigrationsAsync();
if (enAttente.Any())
{
    Console.Error.WriteLine("Migrations en attente. Lancer « make migrate » d'abord.");
    return 1;
}

// Idempotence : le repère est le code court de la soirée à venir. Relancer la commande
// ne doit jamais créer de doublons.
const string codeAVenir = "PLANDEMO";
const string codePasse = "PLANOLD";

if (await db.Events.IgnoreQueryFilters().AnyAsync(e => e.ShortCode == codeAVenir))
{
    Console.WriteLine("Jeu de démonstration déjà installé. Utiliser « make reset-db » pour repartir de zéro.");
    return 0;
}

var maintenant = DateTimeOffset.UtcNow;

// --- Comptes -------------------------------------------------------------------------
// Aucun mot de passe : le hachage arrive au lot 0.8. Ces comptes servent à peupler des
// écrans, pas à se connecter.
var personnes = new[] { "Maxence", "Lucas", "Emma", "Thomas", "Rémi" };
var comptes = personnes
    .Select(nom => new User
    {
        Id = Guid.CreateVersion7(),
        Email = $"{nom.ToLowerInvariant()}@partyplan.local",
        DisplayName = nom,
        EmailVerifiedAt = maintenant,
    })
    .ToList();

db.Users.AddRange(comptes);

// --- Soirée à venir ------------------------------------------------------------------
var aVenir = new Event
{
    Id = Guid.CreateVersion7(),
    Name = "Anniversaire de Maxence",
    Description = "Barbecue puis soirée.",
    StartsAt = maintenant.AddDays(10).Date.AddHours(20).ToUniversalTime(),
    Address = "Replonges",
    InviteToken = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16)),
    ShortCode = codeAVenir,
    CreatedByUserId = comptes[0].Id,
};

db.Events.Add(aVenir);

var statuts = new[]
{
    EventMemberStatus.Going,
    EventMemberStatus.Going,
    EventMemberStatus.Maybe,
    EventMemberStatus.NotGoing,
    EventMemberStatus.Late,
};

var membres = comptes
    .Select((compte, index) => new EventMember
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        UserId = compte.Id,
        DisplayName = compte.DisplayName,
        Status = statuts[index],
        Role = index == 0 ? EventMemberRole.Owner : EventMemberRole.Member,
        ArrivalTime = statuts[index] == EventMemberStatus.Late ? new TimeOnly(22, 0) : null,
        JoinedAt = maintenant.AddDays(-2),
    })
    .ToList();

db.EventMembers.AddRange(membres);

// Un invité sans compte, pour que les écrans traitent ce cas dès le développement.
db.EventMembers.Add(new EventMember
{
    Id = Guid.CreateVersion7(),
    EventId = aVenir.Id,
    UserId = null,
    DisplayName = "Julie (sans compte)",
    Status = EventMemberStatus.Going,
    JoinedAt = maintenant.AddDays(-1),
});

var articles = new (string Nom, decimal Quantite, string? Unite, ShoppingCategory Categorie, int Attributaire)[]
{
    ("Bières", 24, "bouteilles", ShoppingCategory.Drinks, 1),
    ("Coca", 3, "bouteilles", ShoppingCategory.Drinks, 0),
    ("Eau", 6, "bouteilles", ShoppingCategory.Drinks, -1),
    ("Jus d'orange", 2, "bouteilles", ShoppingCategory.Drinks, -1),
    ("Merguez", 20, null, ShoppingCategory.Food, 2),
    ("Chips", 4, "paquets", ShoppingCategory.Food, -1),
    ("Pain", 5, "baguettes", ShoppingCategory.Food, 0),
    ("Glaçons", 2, "sacs", ShoppingCategory.Supplies, -1),
    ("Gobelets", 50, null, ShoppingCategory.Supplies, -1),
    ("Charbon", 1, "sac", ShoppingCategory.Supplies, 4),
};

var position = 0;
foreach (var article in articles)
{
    var pris = article.Attributaire >= 0;

    db.ShoppingItems.Add(new ShoppingItem
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        Name = article.Nom,
        Quantity = article.Quantite,
        Unit = article.Unite,
        Category = article.Categorie,
        AssignedMemberId = pris ? membres[article.Attributaire].Id : null,
        AssignedAt = pris ? maintenant.AddHours(-6) : null,
        Position = position++,
        CreatedByMemberId = membres[0].Id,
    });
}

db.EventScheduleItems.AddRange(
    new EventScheduleItem
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        StartsAt = aVenir.StartsAt.AddHours(-2),
        Label = "Préparation",
        CreatedByMemberId = membres[0].Id,
    },
    new EventScheduleItem
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        StartsAt = aVenir.StartsAt.AddHours(-1),
        Label = "Barbecue",
        Location = "Jardin",
        CreatedByMemberId = membres[0].Id,
    },
    new EventScheduleItem
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        StartsAt = aVenir.StartsAt,
        Label = "Arrivée des invités",
        ReminderMinutesBefore = 60,
        CreatedByMemberId = membres[0].Id,
    });

db.ActivityEntries.AddRange(
    new ActivityEntry
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        MemberId = membres[1].Id,
        ActorName = membres[1].DisplayName,
        Kind = ActivityKinds.MemberStatusChanged,
        CreatedAt = maintenant.AddHours(-8),
    },
    new ActivityEntry
    {
        Id = Guid.CreateVersion7(),
        EventId = aVenir.Id,
        MemberId = membres[2].Id,
        ActorName = membres[2].DisplayName,
        Kind = ActivityKinds.ItemClaimed,
        Payload = """{"article":"Merguez"}""",
        CreatedAt = maintenant.AddHours(-6),
    });

// --- Soirée passée -------------------------------------------------------------------
var passe = new Event
{
    Id = Guid.CreateVersion7(),
    Name = "Week-end camping",
    Description = "Trois jours en Ardèche.",
    StartsAt = maintenant.AddDays(-25).Date.AddHours(18).ToUniversalTime(),
    EndsAt = maintenant.AddDays(-23).Date.AddHours(16).ToUniversalTime(),
    Address = "Vallon-Pont-d'Arc",
    InviteToken = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16)),
    ShortCode = codePasse,
    CreatedByUserId = comptes[1].Id,
};

db.Events.Add(passe);

db.EventMembers.AddRange(comptes.Take(3).Select((compte, index) => new EventMember
{
    Id = Guid.CreateVersion7(),
    EventId = passe.Id,
    UserId = compte.Id,
    DisplayName = compte.DisplayName,
    Status = EventMemberStatus.Going,
    Role = index == 1 ? EventMemberRole.Owner : EventMemberRole.Member,
    JoinedAt = maintenant.AddDays(-30),
}));

await db.SaveChangesAsync();

Console.WriteLine($"Comptes créés          : {comptes.Count} ({string.Join(", ", personnes)})");
Console.WriteLine($"Soirée à venir         : {aVenir.Name} — code {codeAVenir}");
Console.WriteLine($"  membres              : {membres.Count} + 1 invité sans compte");
Console.WriteLine($"  articles de courses  : {articles.Length}, dont {articles.Count(a => a.Attributaire >= 0)} attribués");
Console.WriteLine($"Événement passé        : {passe.Name} — code {codePasse}");
Console.WriteLine();
Console.WriteLine("Dépenses et remboursements non installés : la répartition au centime");
Console.WriteLine("(§6.2) arrive au lot 1.8. Écrire ici un second calcul, provisoire,");
Console.WriteLine("créerait une deuxième source de vérité sur la règle la plus sensible");
Console.WriteLine("du produit.");

return 0;
