# Notifications immédiates et réglage par soirée — plan d'implémentation

> **Pour un exécutant agentique :** SOUS-SKILL REQUIS — `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans`. Les étapes sont en cases à cocher.

**But** : qu'un message, un sondage, une dépense ou un achat prévienne les autres dans la
seconde, et que chacun règle ce qu'il reçoit soirée par soirée.

**Architecture** : l'inscription des notifications reste dans la transaction de l'action
métier ; après validation, le service réveille l'expéditeur au lieu de le laisser attendre
son tour d'horloge. Une table d'écarts par soirée surcharge les préférences globales,
catégorie par catégorie. Le regroupement quitte le serveur pour la clé de groupe de
l'appareil.

**Pile** : ASP.NET Core 10, EF Core, PostgreSQL, xUnit ; Flutter 3.38 côté écran.

**Spec** : `docs/superpowers/specs/2026-08-30-notifications-immediates-et-par-soiree-design.md`

## Contraintes globales

- **Français** dans l'interface et la documentation, **anglais** dans le code et les
  identifiants de base (`CLAUDE.md`).
- **Frontières de modules** : un module n'accède jamais aux tables d'un autre. La mise en
  file passe par `IFileNotifications`, dans `PartyPlan.SharedKernel/Contracts`.
- **Cloisonnement** (`RG-SEC-01`) : toute lecture remonte `User → EventMember → Event`.
  L'ordonnanceur ouvre le périmètre événement par événement, jamais globalement.
- **TDD non négociable** : test rouge, exécution qui échoue, implémentation minimale,
  test vert, commit.
- **Voix de l'interface** (`DESIGN.md`) : tutoiement, phrases courtes, aucun point
  d'exclamation dans une erreur, jamais de tiret cadratin dans une chaîne d'interface.
- **Commits conventionnels avec périmètre** : `feat(notifications):`, `fix(messages):`.
- **Assertions en Shouldly**, jamais `Assert.*` : 57 fichiers de test du dépôt
  emploient `ShouldBe`, aucun n'emploie `Assert`. Correspondances —
  `ShouldBeTrue()`, `ShouldBeFalse()`, `x.ShouldBe(attendu)`,
  `collection.ShouldContain(prédicat)`, `.ShouldNotContain(…)`,
  `.ShouldHaveSingleItem()`. Si un extrait de ce plan porte encore un `Assert.`,
  c'est une coquille : transposer, ne pas recopier.
- `make verif` avant tout push.

---

### Tâche 1 : les quatre catégories, leur drapeau, et l'amendement du cahier des charges

**Fichiers :**
- Modifier : `api/src/PartyPlan.SharedKernel/Contracts/IFileNotifications.cs`
- Modifier : `docs/cahier-des-charges.md:661-670`
- Test : `api/tests/PartyPlan.UnitTests/DomainRulesTests.cs`

**Interfaces :**
- Produit : `NotificationCategories.DiscussionMessage`, `.DiscussionMention`,
  `.PollNew`, `.ExpenseNew` — des `const string` ;
  `NotificationCategories.EstImmediate(string categorie) → bool`.

- [ ] **Étape 1 : écrire le test rouge**

```csharp
[Fact]
public void Les_categories_immediates_sont_celles_declenchees_par_un_geste_humain()
{
    NotificationCategories.EstImmediate(NotificationCategories.DiscussionMessage).ShouldBeTrue();
    NotificationCategories.EstImmediate(NotificationCategories.DiscussionMention).ShouldBeTrue();
    NotificationCategories.EstImmediate(NotificationCategories.PollNew).ShouldBeTrue();
    NotificationCategories.EstImmediate(NotificationCategories.ExpenseNew).ShouldBeTrue();
    NotificationCategories.EstImmediate(NotificationCategories.Activity).ShouldBeTrue();

    NotificationCategories.EstImmediate(NotificationCategories.EventStartingSoon).ShouldBeFalse();
    NotificationCategories.EstImmediate(NotificationCategories.BalanceDue).ShouldBeFalse();
}

[Fact]
public void Toute_categorie_est_declaree_dans_All()
{
    // `All` sert l'écran des préférences : une catégorie absente devient invisible
    // et donc non désactivable, ce que EF-NOT-07 interdit.
    NotificationCategories.All.ShouldContain(NotificationCategories.DiscussionMessage);
    NotificationCategories.All.ShouldContain(NotificationCategories.DiscussionMention);
    NotificationCategories.All.ShouldContain(NotificationCategories.PollNew);
    NotificationCategories.All.ShouldContain(NotificationCategories.ExpenseNew);
    NotificationCategories.All.Length.ShouldBe(11);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.UnitTests --filter DomainRulesTests`
Attendu : ÉCHEC, `DiscussionMessage` n'existe pas.

- [ ] **Étape 3 : implémenter**

Dans `IFileNotifications.cs`, à la suite des sept constantes existantes :

```csharp
    /// <summary>Message posté dans la discussion, sans citation.</summary>
    public const string DiscussionMessage = "discussion.message";

    /// <summary>Message citant nommément le destinataire.</summary>
    public const string DiscussionMention = "discussion.mention";

    public const string PollNew = "poll.new";
    public const string ExpenseNew = "expense.new";

    public static readonly string[] All =
    [
        InvitationAnswer, EventChanged, InvitationPending, ShoppingUnclaimed,
        EventStartingSoon, BalanceDue, Activity,
        DiscussionMessage, DiscussionMention, PollNew, ExpenseNew,
    ];

    /// <summary>
    /// La catégorie part-elle sans attendre le tour d'horloge ?
    /// <para>
    /// Vrai lorsqu'un humain vient d'agir : la notification annonce un geste que son
    /// auteur croit déjà connu des autres. Faux pour un rappel calculé, que personne
    /// n'a demandé à cet instant — d'où le silence nocturne qui ne vaut que pour lui
    /// (RG-NOT-01, amendée le 30/08/2026).
    /// </para>
    /// </summary>
    public static bool EstImmediate(string categorie) => categorie is
        DiscussionMessage or DiscussionMention or PollNew or ExpenseNew or Activity;
```

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.UnitTests --filter DomainRulesTests` → SUCCÈS.

- [ ] **Étape 5 : amender le cahier des charges**

Dans `docs/cahier-des-charges.md`, remplacer les lignes `EF-NOT-03`, `EF-NOT-10`,
`RG-NOT-01` et `RG-NOT-02` :

```markdown
| EF-NOT-03 | P0 | Rappeler à un membre qu'il n'a pas répondu à l'invitation (J-7, J-3 et J-1). |
| EF-NOT-10 | P0 | Notifier l'activité de l'événement : article pris en charge, article acheté, message posté, sondage créé, dépense ajoutée. |

**RG-NOT-01** — Aucune notification **planifiée** n'est envoyée entre 22 h et 8 h heure
locale du destinataire, sauf le rappel de début d'événement. Une notification déclenchée
par un geste humain — message, sondage, dépense, achat — part quelle que soit l'heure :
la soirée est ce qui se passe le soir, et une conversation à 23 h est le cas d'usage.
*Amendée le 30/08/2026.*

**RG-NOT-02** — Les notifications d'activité ne sont pas regroupées par le serveur. Elles
portent une clé de groupe par événement, et c'est l'appareil qui les empile sous un seul
bandeau. Sur le Web, la notion équivalente remplace au lieu d'empiler : le navigateur
montre la dernière. *Amendée le 30/08/2026 ; le plafond d'une notification par quart
d'heure retardait la discussion au-delà de la conversation qu'elle annonçait.*
```

- [ ] **Étape 6 : commit**

```bash
git add api/src/PartyPlan.SharedKernel/Contracts/IFileNotifications.cs \
        api/tests/PartyPlan.UnitTests/DomainRulesTests.cs \
        docs/cahier-des-charges.md
git commit -m "feat(notifications): quatre catégories immédiates, et l'amendement des règles"
```

---

### Tâche 2 : la table d'écarts par soirée, et sa résolution

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Notifications/Domain/Notification.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/Persistence/Configurations/RemainingModulesConfiguration.cs`
- Créer : la migration, par `make migration NOM=PreferencesDeNotificationParEvenement`
- Modifier : `api/src/PartyPlan.Modules.Notifications/Application/EnvoiNotifications.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/EnvoiNotificationsTests.cs`

**Interfaces :**
- Consomme : `NotificationCategories.All` (tâche 1).
- Produit : l'entité `EventNotificationPreference { Guid Id; Guid UserId; Guid EventId;
  string Category; bool Enabled; DateTimeOffset UpdatedAt; }`, et dans
  `EnvoiNotifications` la méthode privée
  `bool EstAutorisee(Notification n, IReadOnlyDictionary<(Guid, Guid, string), bool> ecarts, IReadOnlyDictionary<(Guid, string), bool> globales, IReadOnlySet<(Guid, Guid)> sourdines)`.

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task Un_ecart_de_soiree_l_emporte_sur_la_preference_globale()
{
    // Globalement coupée, autorisée sur cette soirée : la notification part.
    await PoserPreferenceGlobaleAsync(_utilisateur, NotificationCategories.DiscussionMessage, actif: false);
    await PoserEcartDeSoireeAsync(_utilisateur, _evenement, NotificationCategories.DiscussionMessage, actif: true);

    var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

    partis.ShouldBe(1);
}

[Fact]
public async Task La_sourdine_l_emporte_sur_un_ecart_qui_autorise()
{
    await PoserEcartDeSoireeAsync(_utilisateur, _evenement, NotificationCategories.DiscussionMessage, actif: true);
    await MettreEnSourdineAsync(_utilisateur, _evenement);

    var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

    partis.ShouldBe(0);
}

[Fact]
public async Task Sans_ecart_la_preference_globale_s_applique()
{
    await PoserPreferenceGlobaleAsync(_utilisateur, NotificationCategories.DiscussionMessage, actif: false);

    var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

    partis.ShouldBe(0);
}

[Fact]
public async Task Sans_rien_de_pose_la_notification_part()
{
    var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

    partis.ShouldBe(1);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter EnvoiNotificationsTests`
Attendu : ÉCHEC, `PoserEcartDeSoireeAsync` n'existe pas.

- [ ] **Étape 3 : l'entité et sa configuration**

Dans `Notification.cs`, après `EventMuteSetting` :

```csharp
/// <summary>
/// Écart au réglage global, pour une soirée et une catégorie.
/// <para>
/// La table ne contient <b>que les écarts</b> : une soirée réglée comme d'habitude n'y
/// a aucune ligne. Y écrire l'état résolu de chaque catégorie ferait d'un changement de
/// préférence globale un changement sans effet sur les soirées déjà ouvertes.
/// </para>
/// </summary>
public sealed class EventNotificationPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid EventId { get; set; }
    public string Category { get; set; } = string.Empty;
    public bool Enabled { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
```

Dans `RemainingModulesConfiguration.cs` :

```csharp
internal sealed class EventNotificationPreferenceConfiguration
    : IEntityTypeConfiguration<EventNotificationPreference>
{
    public void Configure(EntityTypeBuilder<EventNotificationPreference> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Category).HasMaxLength(64);
        builder.HasIndex(p => new { p.UserId, p.EventId, p.Category }).IsUnique();
    }
}
```

Dans `PartyPlanDbContext.cs`, à côté de `EventMuteSettings` (ligne 133) :

```csharp
    public DbSet<EventNotificationPreference> EventNotificationPreferences
        => Set<EventNotificationPreference>();
```

Sans ce `DbSet`, l'entité n'est pas dans le modèle et `dotnet ef migrations add` produit
une migration vide — sans erreur, ce qui est le pire des deux cas. `SnakeCaseNaming`
donnera la table `event_notification_preferences`, et il n'y a donc aucun `ToTable` à
écrire.

Il faut aussi l'exposer au module Notifications par son contexte cloisonné : ajouter
`DbSet<EventNotificationPreference> EventNotificationPreferences { get; }` à
`INotificationsDbContext`, faute de quoi `EnvoiNotifications` ne pourra pas la lire sans
enfreindre la frontière de modules (règle 6).

- [ ] **Étape 4 : la migration**

```bash
make migration NOM=PreferencesDeNotificationParEvenement
make migrate
```

- [ ] **Étape 5 : la résolution**

Dans `EnvoiNotifications.cs`, charger les écarts à côté des préférences existantes
(ligne 59) et remplacer le test des lignes 83-90 :

```csharp
        var ecarts = await db.EventNotificationPreferences
            .Where(p => destinataires.Contains(p.UserId))
            .ToDictionaryAsync(
                p => (p.UserId, p.EventId, p.Category),
                p => p.Enabled,
                cancellationToken)
            .ConfigureAwait(false);
```

```csharp
            // L'ordre est la règle : sourdine, puis écart de la soirée, puis global,
            // puis valeur d'usine. La sourdine reste une notion distincte plutôt qu'une
            // liste de « non » — une catégorie ajoutée demain doit rester muette sur une
            // soirée mise en sourdine, ce qu'une liste figée laisserait passer.
            if (notification.EventId is { } evenement
                && sourdines.Contains((notification.UserId!.Value, evenement)))
            {
                Horodater(notification);
                continue;
            }

            var autorisee =
                ecarts.TryGetValue(
                    (notification.UserId!.Value, notification.EventId ?? Guid.Empty, notification.Category),
                    out var ecart)
                    ? ecart
                    : !preferences.Any(p =>
                        p.UserId == notification.UserId
                        && p.Category == notification.Category
                        && !p.PushEnabled);

            if (!autorisee)
            {
                Horodater(notification);
                continue;
            }
```

- [ ] **Étape 6 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter EnvoiNotificationsTests` → SUCCÈS.

- [ ] **Étape 7 : commit**

```bash
git add api/src api/tests docs
git commit -m "feat(notifications): réglage par soirée, en surcharge du réglage global"
```

---

### Tâche 3 : le réveil de l'expéditeur

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IReveilNotifications.cs`
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/ReveilNotifications.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/Notifications/OrdonnanceurNotifications.cs:71-93`
- Test : `api/tests/PartyPlan.IntegrationTests/ReveilNotificationsTests.cs`

**Interfaces :**
- Produit : `IReveilNotifications { void Reveiller(); }`, injectable dans les services
  métier ; `OrdonnanceurNotifications.PasseDEnvoiAsync(DateTimeOffset, CancellationToken)`.

- [ ] **Étape 1 : écrire le test rouge**

```csharp
[Fact]
public async Task Le_reveil_envoie_sans_relancer_la_planification()
{
    // Le réveil ne doit déclencher que la seconde passe : recalculer les rappels de
    // toutes les soirées à chaque message est un coût sans contrepartie.
    var planificateur = new PlanificateurCompteur();
    await using var pile = await PileAvecAsync(planificateur);

    await EnfilerNotificationImmediateAsync(pile);
    pile.Reveil.Reveiller();
    await pile.AttendreEnvoiAsync();

    pile.NotificationsParties.ShouldBe(1);
    planificateur.Appels.ShouldBe(0);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter ReveilNotificationsTests`
Attendu : ÉCHEC, `IReveilNotifications` n'existe pas.

- [ ] **Étape 3 : le contrat**

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Réveille la passe d'envoi sans attendre le tour d'horloge.
/// <para>
/// Appelé <b>après</b> la validation de la transaction métier, jamais pendant : une
/// notification inscrite mais non validée ne doit pas partir. Le réveil est un signal
/// en mémoire, ce que l'instance unique déjà imposée par l'ordonnanceur autorise
/// (<c>docs/exploitation.md</c> §1.2).
/// </para>
/// <para>
/// Ne réveille que l'envoi. La planification reste à la cadence : la relancer à chaque
/// message recalculerait les rappels de toutes les soirées.
/// </para>
/// </summary>
public interface IReveilNotifications
{
    void Reveiller();
}
```

- [ ] **Étape 4 : l'implémentation**

```csharp
namespace PartyPlan.Infrastructure.Notifications;

/// <summary>
/// Signal de réveil. Un sémaphore borné à un jeton plutôt qu'une file : dix messages
/// simultanés doivent produire une passe d'envoi, pas dix.
/// </summary>
public sealed class ReveilNotifications : IReveilNotifications, IDisposable
{
    private readonly SemaphoreSlim _signal = new(0, 1);

    public void Reveiller()
    {
        // Le sémaphore est déjà armé : une passe est due, inutile d'en demander une
        // seconde. Release lèverait au-delà du plafond, d'où le try.
        try
        {
            _signal.Release();
        }
        catch (SemaphoreFullException)
        {
        }
    }

    internal Task AttendreAsync(TimeSpan delai, CancellationToken cancellationToken)
        => _signal.WaitAsync(delai, cancellationToken);

    public void Dispose() => _signal.Dispose();
}
```

- [ ] **Étape 4 bis : enregistrer le réveil en singleton**

Dans `api/src/PartyPlan.Infrastructure/DependencyInjection.cs` :

```csharp
        // Singleton, et c'est la seule portée qui marche : le service métier qui
        // réveille vit dans la portée d'une requête HTTP, l'ordonnanceur qui attend vit
        // pour la durée du processus. En portée de requête, chacun tiendrait son propre
        // sémaphore et le signal n'arriverait jamais — sans erreur, sans journal, avec
        // pour seul symptôme des notifications qui repassent à la cadence d'une minute.
        services.AddSingleton<ReveilNotifications>();
        services.AddSingleton<IReveilNotifications>(f => f.GetRequiredService<ReveilNotifications>());
```

Le double enregistrement donne à l'ordonnanceur la classe concrète, dont il appelle
`AttendreAsync` — `internal`, donc visible depuis le même assemblage — pendant que les
modules métier ne voient que l'interface.

- [ ] **Étape 5 : la boucle de l'ordonnanceur**

Ajouter `ReveilNotifications reveil` au constructeur primaire de la classe, qui ne le
porte pas encore :

```csharp
public sealed class OrdonnanceurNotifications(
    IServiceScopeFactory portees,
    IClock clock,
    IOptions<OrdonnanceurOptions> options,
    ReveilNotifications reveil,
    ILogger<OrdonnanceurNotifications> logger) : BackgroundService
```

Puis remplacer l'attente fixe :

```csharp
            try
            {
                // Réveillé : on n'envoie que. Non réveillé au bout de la cadence : passe
                // complète, planification comprise.
                var reveille = await reveil
                    .AttendreAsync(_options.Cadence, stoppingToken)
                    .ConfigureAwait(false);

                if (reveille)
                {
                    await PasseDEnvoiAsync(clock.UtcNow, stoppingToken).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException)
            {
                return;
            }
```

- [ ] **Étape 6 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter ReveilNotificationsTests` → SUCCÈS.

- [ ] **Étape 7 : commit**

```bash
git add api/src api/tests
git commit -m "feat(notifications): réveiller l'envoi après validation, sans replanifier"
```

---

### Tâche 4 : le déclencheur des messages

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Messages/Application/MessageService.cs:388-470`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsDiscussionTests.cs` *(créer)*

**Interfaces :**
- Consomme : `IFileNotifications.Enfiler`, `IReveilNotifications.Reveiller`,
  `NotificationCategories.DiscussionMessage` et `.DiscussionMention` (tâches 1 et 3).

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task Un_message_notifie_les_autres_membres_jamais_son_auteur()
{
    await EnvoyerMessageAsync(_auteur, "On se retrouve à 20h.");

    var notifs = await NotificationsAsync();

    notifs.ShouldNotContain(n => n.UserId == _auteur.UserId);
    notifs.ShouldContain(n => n.UserId == _lucas.UserId
        && n.Category == NotificationCategories.DiscussionMessage);
}

[Fact]
public async Task Une_personne_citee_recoit_sa_mention_meme_si_le_bavardage_est_coupe()
{
    // C'est le sens du découpage en deux catégories : couper le bavardage ne coupe pas
    // le fait d'être appelé nommément.
    await PoserPreferenceGlobaleAsync(_lucas.UserId, NotificationCategories.DiscussionMessage, actif: false);

    await EnvoyerMessageAsync(_auteur, "@Lucas tu ramènes la glace ?", cite: [_lucas.MemberId]);

    var partis = await EnvoyerLesDuesAsync();

    partis.ShouldBe(1);
}

[Fact]
public async Task Une_personne_citee_ne_recoit_pas_aussi_le_message_simple()
{
    await EnvoyerMessageAsync(_auteur, "@Lucas tu ramènes la glace ?", cite: [_lucas.MemberId]);

    var notifs = await NotificationsAsync();

    notifs.Where(n => n.UserId == _lucas.UserId).ShouldHaveSingleItem();
    notifs.Single(n => n.UserId == _lucas.UserId).Category.ShouldBe(NotificationCategories.DiscussionMention);
}

[Fact]
public async Task Un_membre_sans_compte_n_est_jamais_notifie()
{
    await EnvoyerMessageAsync(_auteur, "Salut.");

    var notifs = await NotificationsAsync();

    notifs.ShouldNotContain(n => n.UserId is null);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsDiscussionTests`
Attendu : ÉCHEC, aucune notification produite.

- [ ] **Étape 3 : injecter les deux dépendances**

```csharp
public sealed class MessageService(
    IMessagesDbContext db,
    IEventMembership membership,
    IEventImageStorage images,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IFileNotifications notifications,
    IReveilNotifications reveil) : IPollAnnouncement
```

- [ ] **Étape 4 : enfiler, à la fin de `EnvoyerAsync`, avant le `SaveChangesAsync`**

```csharp
        var cites = mentions.ToHashSet();
        var extrait = message.Body is { Length: > 0 } corps
            ? corps.Length <= 120 ? corps : corps[..117] + "…"
            : "a envoyé une image";

        // `membres` est déjà en portée : `EnvoyerAsync` a appelé `ListActiveAsync` plus
        // haut pour valider les personnes citées. Ne pas rappeler le contrat.
        foreach (var membre in membres)
        {
            if (membre.MemberId == moi.MemberId || membre.UserId is not { } compte)
            {
                continue;
            }

            var citee = cites.Contains(membre.MemberId);

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                eventId,
                citee ? NotificationCategories.DiscussionMention : NotificationCategories.DiscussionMessage,
                citee ? $"{moi.DisplayName} t'a cité" : moi.DisplayName,
                extrait,
                $"/events/{eventId}",
                clock.UtcNow,
                // L'identifiant du message, et non un quart d'heure : chaque message a
                // sa notification, l'appareil se chargeant de les empiler.
                $"{eventId}:{(citee ? "mention" : "message")}:{compte}:{message.Id}"));
        }
```

Et après le `SaveChangesAsync` de la méthode :

```csharp
        // Après validation, jamais avant : une transaction en échec ne doit réveiller
        // personne pour une notification qui n'existera pas.
        reveil.Reveiller();
```

- [ ] **Étape 5 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsDiscussionTests` → SUCCÈS.

- [ ] **Étape 6 : commit**

```bash
git add api/src/PartyPlan.Modules.Messages api/tests
git commit -m "feat(messages): un message notifie les autres, une citation notifie à part"
```

---

### Tâche 5 : le déclencheur des sondages

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Polls/Application/PollService.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsSondagesTests.cs` *(créer)*

**Interfaces :**
- Consomme : `IFileNotifications.Enfiler`, `IReveilNotifications.Reveiller`,
  `NotificationCategories.PollNew`.

- [ ] **Étape 1 : écrire le test rouge**

```csharp
[Fact]
public async Task Un_sondage_notifie_tous_les_membres_sauf_son_auteur()
{
    await CreerSondageAsync(_auteur, "On prend quoi en dessert ?", ["Tarte", "Glaces"]);

    var notifs = await NotificationsAsync();

    notifs.ShouldNotContain(n => n.UserId == _auteur.UserId);
    notifs.ShouldContain(n => n.UserId == _lucas.UserId
        && n.Category == NotificationCategories.PollNew);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsSondagesTests`
Attendu : ÉCHEC, aucune notification produite.

- [ ] **Étape 3 : implémenter**

Injecter `IFileNotifications notifications, IReveilNotifications reveil` dans
`PollService`, puis à la création, avant `SaveChangesAsync` :

```csharp
        foreach (var membre in await membership.ListActiveAsync(eventId, cancellationToken))
        {
            if (membre.MemberId == moi.MemberId || membre.UserId is not { } compte)
            {
                continue;
            }

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                eventId,
                NotificationCategories.PollNew,
                "Nouveau sondage",
                sondage.Question,
                $"/events/{eventId}/sondages",
                clock.UtcNow,
                $"{eventId}:{NotificationCategories.PollNew}:{compte}:{sondage.Id}"));
        }
```

Et après `SaveChangesAsync` : `reveil.Reveiller();`

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsSondagesTests` → SUCCÈS.

- [ ] **Étape 5 : commit**

```bash
git add api/src/PartyPlan.Modules.Polls api/tests
git commit -m "feat(polls): un sondage créé prévient les membres"
```

---

### Tâche 6 : le déclencheur des dépenses

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Expenses/Application/ExpenseService.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsDepensesTests.cs` *(créer)*

**Interfaces :**
- Consomme : `IFileNotifications.Enfiler`, `IReveilNotifications.Reveiller`,
  `NotificationCategories.ExpenseNew`.

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task Une_depense_ne_notifie_que_les_porteurs_d_une_part()
{
    // Être averti d'une dépense dont on ne porte aucune part est du bruit, et le bruit
    // fait couper la catégorie entière.
    await CreerDepenseAsync(_maxence, "Courses", 40m, participants: [_maxence.MemberId, _lucas.MemberId]);

    var notifs = await NotificationsAsync();

    notifs.ShouldContain(n => n.UserId == _lucas.UserId);
    notifs.ShouldNotContain(n => n.UserId == _emma.UserId);
}

[Fact]
public async Task Le_payeur_n_est_pas_notifie_de_sa_propre_depense()
{
    await CreerDepenseAsync(_maxence, "Courses", 40m, participants: [_maxence.MemberId, _lucas.MemberId]);

    var notifs = await NotificationsAsync();

    notifs.ShouldNotContain(n => n.UserId == _maxence.UserId);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsDepensesTests`
Attendu : ÉCHEC, aucune notification produite.

- [ ] **Étape 3 : implémenter**

Injecter `IFileNotifications notifications, IReveilNotifications reveil`, puis à la
création, avant `SaveChangesAsync` :

```csharp
        var montant = depense.Amount.ToString("0.00", CultureInfo.GetCultureInfo("fr-FR"));

        foreach (var part in depense.Participants)
        {
            var membre = membres.FirstOrDefault(m => m.MemberId == part.MemberId);

            if (membre is null || membre.MemberId == payeur.MemberId || membre.UserId is not { } compte)
            {
                continue;
            }

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                eventId,
                NotificationCategories.ExpenseNew,
                "Nouvelle dépense",
                $"{payeur.DisplayName} a ajouté {depense.Label} pour {montant} €.",
                $"/events/{eventId}",
                clock.UtcNow,
                $"{eventId}:{NotificationCategories.ExpenseNew}:{compte}:{depense.Id}"));
        }
```

Et après `SaveChangesAsync` : `reveil.Reveiller();`

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsDepensesTests` → SUCCÈS.

- [ ] **Étape 5 : commit**

```bash
git add api/src/PartyPlan.Modules.Expenses api/tests
git commit -m "feat(expenses): une dépense prévient ceux qui en portent une part"
```

---

### Tâche 7 : l'achat d'un article, et le retrait du regroupement

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Shopping/Application/ShoppingService.cs:488-530`
- Modifier : `api/src/PartyPlan.Modules.Notifications/Application/FileNotifications.cs:81-95`
- Test : `api/tests/PartyPlan.IntegrationTests/FileNotificationsTests.cs`

**Interfaces :**
- Consomme : `IReveilNotifications.Reveiller` (tâche 3).

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task Un_achat_previent_les_autres_membres()
{
    await AcheterAsync(_lucas, _bieres, quantite: 24, prix: 21.60m);

    var notifs = await NotificationsAsync();

    notifs.ShouldContain(n => n.UserId == _maxence.UserId
        && n.Category == NotificationCategories.Activity);
}

[Fact]
public async Task Deux_activites_dans_le_meme_quart_d_heure_produisent_deux_notifications()
{
    // RG-NOT-02 amendée : le serveur ne plafonne plus, l'appareil empile.
    await PrendreEnChargeAsync(_lucas, _bieres);
    await PrendreEnChargeAsync(_lucas, _pain);

    var notifs = await NotificationsAsync();

    notifs.Count(n => n.UserId == _maxence.UserId).ShouldBe(2);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FileNotificationsTests`
Attendu : ÉCHEC — aucune notification sur l'achat, et une seule sur deux prises en charge.

- [ ] **Étape 3 : retirer le plafond de `FileNotifications`**

Supprimer le cas particulier des lignes 81-95, qui écartait une seconde notification
`Activity` dans le même quart d'heure. Remplacer le commentaire de la méthode par :

```csharp
    // Aucun plafond depuis le 30/08/2026 : chaque geste produit sa notification, et
    // c'est la clé de groupe de l'appareil qui les empile sous un seul bandeau. Le
    // plafond au quart d'heure retardait la discussion au-delà de la conversation
    // qu'il annonçait.
```

- [ ] **Étape 4 : appeler sur l'achat**

Dans `ShoppingService`, après la consignation de l'achat, ajouter l'appel qui existe
déjà pour la prise en charge :

```csharp
        await PrevenirDeLActiviteAsync(
                eventId,
                contexte.MoiId,
                $"{contexte.MonNom} a acheté {contexte.Article.Name}.",
                cancellationToken)
            .ConfigureAwait(false);
```

Et après le `SaveChangesAsync` des deux chemins : `reveil.Reveiller();`

- [ ] **Étape 5 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter FileNotificationsTests` → SUCCÈS.

- [ ] **Étape 6 : commit**

```bash
git add api/src api/tests
git commit -m "feat(shopping): un achat prévient, et le plafond au quart d'heure disparaît"
```

---

### Tâche 8 : supprimer la plage de silence

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Notifications/Application/EnvoiNotifications.cs`
- Modifier : `docs/cahier-des-charges.md`
- Test : `api/tests/PartyPlan.IntegrationTests/EnvoiNotificationsTests.cs`

**Interfaces :**
- Retire : `EnvoiNotifications.EnHeureCreuse`, les constantes `DebutDuSilence` et
  `FinDuSilence`, et le report qui en découlait.

**Pourquoi.** `RG-NOT-01` réimplémentait, moins bien, une fonction que tout téléphone
possède : qui ne veut pas être dérangé active « ne pas déranger ». Pire, la règle
retardait à 8 h du matin des notifications de soirée qui ne servent plus à rien à cette
heure-là. Le système d'exploitation décide, l'application n'a pas à en juger.

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task Une_notification_part_a_23h()
{
    var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage, heureLocale: 23);

    partis.ShouldBe(1);
}

[Fact]
public async Task Un_rappel_part_aussi_a_23h()
{
    // Plus aucune catégorie n'est reportée : le téléphone tranche, pas le serveur.
    var partis = await EnvoyerAsync(NotificationCategories.InvitationPending, heureLocale: 23);

    partis.ShouldBe(1);
}
```

Et **supprimer** les tests existants qui affirment le report nocturne — ils figent une
règle qui n'existe plus. Les repérer par `SentAt.ShouldBeNull()` associé à une heure
locale nocturne.

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter EnvoiNotificationsTests`
Attendu : ÉCHEC, `Un_rappel_part_aussi_a_23h` obtient 0.

- [ ] **Étape 3 : retirer le silence**

Supprimer la méthode `EnHeureCreuse`, son appel, les constantes `DebutDuSilence` et
`FinDuSilence`, et la branche qui laissait la notification sans horodatage pour la
reporter. Le fuseau du destinataire n'est plus lu pour cette raison — vérifier s'il sert
encore ailleurs avant de retirer la lecture des profils.

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter EnvoiNotificationsTests` → SUCCÈS.

- [ ] **Étape 5 : amender le cahier des charges**

Dans `docs/cahier-des-charges.md`, remplacer `RG-NOT-01` par :

```markdown
**RG-NOT-01** — *Retirée le 30/08/2026.* Aucune plage de silence n'est appliquée par le
serveur. Les systèmes mobiles offrent tous un mode « ne pas déranger », mieux fait et
déjà réglé par la personne ; le dupliquer côté serveur retardait en outre les
notifications d'une soirée jusqu'au lendemain matin, quand elles ne servaient plus.
```

Retirer aussi la mention de l'exception du rappel de début, devenue sans objet.

- [ ] **Étape 6 : commit**

```bash
git add api docs
git commit -m "feat(notifications)!: retirer la plage de silence, le téléphone la fait mieux"
```

---

### Tâche 9 : les deux endpoints de réglage par soirée

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Notifications/Endpoints/NotificationEndpoints.cs`
- Modifier : `api/src/PartyPlan.Modules.Notifications/Application/NotificationService.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsLectureTests.cs`

**Interfaces :**
- Produit : `GET /v1/events/{eventId}/notifications/preferences` →
  `IReadOnlyList<PreferenceDeSoireeView(string Category, bool Enabled, bool EstUnEcart)>` ;
  `PATCH` du même chemin, corps `{ "category": "...", "enabled": true|null }`.

- [ ] **Étape 1 : écrire les tests rouges**

```csharp
[Fact]
public async Task La_lecture_rend_la_valeur_resolue_et_dit_si_c_est_un_ecart()
{
    // L'écran ne doit pas refaire la résolution : deux implémentations d'une même règle
    // finissent toujours par diverger.
    await PoserPreferenceGlobaleAsync(_moi, NotificationCategories.DiscussionMessage, actif: false);

    var vues = await LirePreferencesDeSoireeAsync(_evenement);

    var vue = vues.Single(v => v.Category == NotificationCategories.DiscussionMessage);
    vue.Enabled.ShouldBeFalse();
    vue.EstUnEcart.ShouldBeFalse();
}

[Fact]
public async Task Une_valeur_nulle_retire_l_ecart()
{
    await EcrirePreferenceDeSoireeAsync(_evenement, NotificationCategories.DiscussionMessage, actif: true);
    await EcrirePreferenceDeSoireeAsync(_evenement, NotificationCategories.DiscussionMessage, actif: null);

    var vues = await LirePreferencesDeSoireeAsync(_evenement);

    vues.Single(v => v.Category == NotificationCategories.DiscussionMessage).EstUnEcart.ShouldBeFalse();
}

[Fact]
public async Task Un_non_membre_recoit_404()
{
    var reponse = await ClientDe(_etranger).GetAsync($"/v1/events/{_evenement}/notifications/preferences");

    reponse.StatusCode.ShouldBe(HttpStatusCode.NotFound);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsLectureTests`
Attendu : ÉCHEC, 404 sur une route inexistante.

- [ ] **Étape 3 : implémenter les deux endpoints**

Dans `NotificationEndpoints.cs`. Il n'existe **pas** de groupe des événements : le
fichier déclare `routes.MapGroup("/notifications")` et, séparément,
`routes.MapGroup("/events/{eventId:guid}/mute")`. Créer un troisième groupe sur le même
modèle que celui de la sourdine :

```csharp
        var parSoiree = routes.MapGroup("/events/{eventId:guid}/notifications")
            .WithTags("Notifications");

        parSoiree.MapGet("/preferences", async (
                Guid eventId,
                NotificationService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .PreferencesDeSoireeAsync(eventId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ListEventNotificationPreferences")
            .WithSummary("Réglages de notification de cette soirée, valeurs résolues.")
            .RequireAuthorization();

        parSoiree.MapPatch("/preferences", async (
                Guid eventId,
                PreferenceDeSoireeBody corps,
                NotificationService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .DefinirPreferenceDeSoireeAsync(eventId, corps.Category, corps.Enabled, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SetEventNotificationPreference")
            .WithSummary("Pose un écart pour cette soirée, ou le retire si `enabled` est nul.")
            .RequireAuthorization();
```

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsLectureTests` → SUCCÈS.

- [ ] **Étape 5 : régénérer le client**

```bash
make openapi
```

- [ ] **Étape 6 : commit**

```bash
git add api docs/api
git commit -m "feat(notifications): endpoints de réglage par soirée"
```

---

### Tâche 10 : la clé de groupe sur l'appareil

**Fichiers :**
- Modifier : `api/src/PartyPlan.Infrastructure/Notifications/FirebasePushSender.cs`
- Modifier : `app/lib/features/notifications/` — la réception
- Test : `api/tests/PartyPlan.UnitTests/FirebasePushSenderTests.cs`

**Interfaces :**
- Consomme : `PushMessage(string DeviceToken, string Title, string Body, string? DeepLink,
  string? GroupKey)` — le champ `GroupKey` est **ajouté par cette tâche** au contrat
  `api/src/PartyPlan.SharedKernel/Contracts/IPushSender.cs`, et rempli par
  `EnvoiNotifications.cs:109` depuis l'`EventId` de la notification. L'émetteur ne peut
  pas le déduire seul : il ne lit pas la table des notifications (règle 6).
- Produit : le message Firebase porte `data.groupe = "event:{eventId}"`.

- [ ] **Étape 1 : écrire le test rouge**

```csharp
[Fact]
public async Task Le_message_porte_une_cle_de_groupe_par_evenement()
{
    // Même couture que les tests existants de ce fichier : la frontière est le
    // HttpClient (NF-DEV-10), et ce qui se vérifie est le corps envoyé.
    var stub = Stub(HttpStatusCode.OK, """{"name":"projects/p/messages/1"}""");
    var emetteur = Creer(stub, new RegistreDeTest());

    await emetteur.SendAsync(
        new PushMessage(Jeton, "Lucas", "On arrive.", "/events/42", GroupKey: "event:42"),
        CancellationToken.None);

    var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
    corps.GetProperty("data").GetProperty("groupe").GetString().ShouldBe("event:42");
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.UnitTests --filter FirebasePushSenderTests`
Attendu : ÉCHEC, la clé `groupe` est absente.

- [ ] **Étape 3 : implémenter côté serveur**

Ajouter au dictionnaire de données du message :

```csharp
            // Empilement sur l'appareil, en remplacement du plafond serveur retiré le
            // 30/08/2026. Android range les notifications d'une même clé sous un seul
            // bandeau ; le Web remplace au lieu d'empiler, ce qui est accepté.
            ["groupe"] = $"event:{notification.EventId}",
```

- [ ] **Étape 4 : implémenter côté application**

Dans la réception Flutter, passer `groupKey: donnees['groupe']` à
`flutter_local_notifications`, et poser une notification de résumé par clé.

- [ ] **Étape 5 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.UnitTests --filter FirebasePushSenderTests` → SUCCÈS.
`cd app && flutter test` → SUCCÈS.

- [ ] **Étape 6 : commit**

```bash
git add api app
git commit -m "feat(notifications): empiler par soirée sur l'appareil"
```

---

### Tâche 11 : J-7, et l'écran de réglage

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Events/Application/RappelsDeReponse.cs`
- Créer : `app/lib/features/evenement/parametres_notifications_page.dart`
- Modifier : `app/lib/app/router.dart`
- Test : `api/tests/PartyPlan.IntegrationTests/NotificationsEvenementiellesTests.cs`
- Test : `app/test/features/parametres_notifications_test.dart`

- [ ] **Étape 1 : écrire le test rouge de J-7**

```csharp
[Fact]
public async Task Un_membre_sans_reponse_est_relance_a_J_moins_7()
{
    await PlanifierAsync(evenementDansJours: 7);

    var notifs = await NotificationsAsync();

    notifs.ShouldContain(n => n.Category == NotificationCategories.InvitationPending);
}
```

- [ ] **Étape 2 : exécuter, vérifier l'échec**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsEvenementiellesTests`
Attendu : ÉCHEC, seuls J-3 et J-1 relancent.

- [ ] **Étape 3 : ajouter l'échéance**

`Echeances` est un tableau de tuples `(int Jours, string Occurrence)`, et non d'entiers :
l'occurrence entre dans la clé de déduplication, sans quoi les trois rappels d'une même
soirée se prendraient l'un pour l'autre.

```csharp
    private static readonly (int Jours, string Occurrence)[] Echeances =
    [
        // J-7 ajouté le 30/08/2026 : à trois jours, une soirée à organiser est déjà
        // tard pour qui doit poser un congé ou trouver un moyen de transport.
        (7, "j-7"),
        (3, "j-3"),
        (1, "j-1"),
    ];
```

Le libellé est aujourd'hui un ternaire binaire sur `echeance.Jours == 1`, qu'une
troisième échéance rend faux — J-7 y hériterait du texte de J-3. Le remplacer :

```csharp
                echeance.Jours switch
                {
                    1 => "La soirée est demain. Dis si tu viens.",
                    3 => "La soirée est dans trois jours. Dis si tu viens.",
                    _ => "La soirée est dans une semaine. Dis si tu viens.",
                },
```

- [ ] **Étape 4 : exécuter, vérifier le succès**

`cd api && dotnet test tests/PartyPlan.IntegrationTests --filter NotificationsEvenementiellesTests` → SUCCÈS.

- [ ] **Étape 5 : écrire le test rouge de l'écran**

```dart
testWidgets('la discussion propose trois choix et écrit deux préférences', (tester) async {
  await _monter(tester);

  await tester.tap(find.text('Seulement les mentions'));
  await tester.pumpAndSettle();

  expect(_api.ecrits, contains(('discussion.message', false)));
  expect(_api.ecrits, contains(('discussion.mention', true)));
});
```

- [ ] **Étape 6 : exécuter, vérifier l'échec**

`cd app && flutter test test/features/parametres_notifications_test.dart`
Attendu : ÉCHEC, l'écran n'existe pas.

- [ ] **Étape 7 : construire l'écran**

Un `ListView` de catégories. La discussion est rendue par un `SegmentedButton` à trois
valeurs — `tout`, `mentions`, `rien` — qui écrit les deux préférences sous-jacentes. Les
autres catégories sont des `SwitchListTile`. Un bouton en pied, « Comme mes réglages
habituels », envoie une valeur nulle pour chaque catégorie.

Jetons de `app/lib/design/tokens.dart` uniquement : aucune couleur, aucun rayon ni
espacement en dur (`CLAUDE.md`).

- [ ] **Étape 8 : exécuter, vérifier le succès**

`cd app && flutter test test/features/parametres_notifications_test.dart` → SUCCÈS.

- [ ] **Étape 9 : vérification complète et feuille de route**

```bash
make verif
```

Puis cocher dans `docs/roadmap.md` le lot 1.11 : déclencheurs de discussion, de sondage,
de dépense et d'achat, réglage par soirée, J-7.

- [ ] **Étape 10 : commit**

```bash
git add api app docs
git commit -m "feat(notifications): J-7, et l'écran de réglage par soirée"
```

---

## Ce que ce plan ne fait pas

- **Aucun repli par courriel** (`EF-NOT-09`), hors périmètre du lot.
- **Aucun réessai d'envoi** : un jeton mort est mis au rebut, ce qui suffit.
- **Aucune file externe**, aucun Redis — le `CLAUDE.md` les écarte, et le réveil en
  mémoire suffit à l'instance unique.
- **Aucune notification de modification ou de suppression.** Seule la création prévient.
- **Le lien profond de la discussion vise `/events/{id}`** et non un onglet précis : les
  onglets ne sont pas des routes dans `router.dart`. Le corriger suppose de les y
  inscrire, ce qui est un chantier distinct — au passage, `ShoppingService` pose
  aujourd'hui `/events/{id}/courses`, une route qui n'existe pas et mène à un écran
  d'erreur.
