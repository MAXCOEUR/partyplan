namespace PartyPlan.Infrastructure.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Administration.Domain;
using PartyPlan.Modules.Administration.Persistence;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.Modules.Expenses.Domain;
using PartyPlan.Modules.Expenses.Persistence;
using PartyPlan.Modules.Messages.Domain;
using PartyPlan.Modules.Messages.Persistence;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.Modules.Polls.Domain;
using PartyPlan.Modules.Polls.Persistence;
using PartyPlan.Modules.Settlements.Domain;
using PartyPlan.Modules.Settlements.Persistence;
using PartyPlan.Modules.Shopping.Domain;
using PartyPlan.Modules.Shopping.Persistence;
using PartyPlan.Modules.Tasks.Domain;
using PartyPlan.Modules.Tasks.Persistence;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Contexte unique de la base (ADR 0002 : un seul monolithe modulaire, une seule base).
/// <para>
/// Il implémente les contrats de persistance de chaque module. Un module ne reçoit que
/// son interface : la frontière de l'ADR 0002 est ainsi vérifiée par le compilateur,
/// et non par une convention.
/// </para>
/// </summary>
public sealed class PartyPlanDbContext(
    DbContextOptions<PartyPlanDbContext> options,
    IEventScope eventScope,
    IClock clock,
    IIdGenerator idGenerator)
    : DbContext(options),
      IUsersDbContext,
      IAdministrationDbContext,
      IEventsDbContext,
      IShoppingDbContext,
      IExpensesDbContext,
      ISettlementsDbContext,
      ITasksDbContext,
      IPollsDbContext,
      IMessagesDbContext,
      INotificationsDbContext
{
    /// <summary>
    /// Tables en ajout seul. Toute tentative de modification ou de suppression est
    /// une anomalie de programmation : RG-ADM-06 pour l'audit, RG-FIL-02 pour le fil
    /// d'activité. Les droits de la base constituent la seconde barrière (NF-SEC-08).
    /// </summary>
    private static readonly Type[] AppendOnlyTypes =
    [
        typeof(AdminAuditEntry),
        typeof(ActivityEntry),
        typeof(ExpenseRevision),
    ];

    /// <summary>Périmètre lu par les filtres globaux. Public par nécessité technique.</summary>
    public Guid[] AllowedEventIds => eventScope.AllowedEventIds;

    // --- Users ---
    public DbSet<User> Users => Set<User>();

    public DbSet<Session> Sessions => Set<Session>();

    public DbSet<Group> Groups => Set<Group>();

    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();

    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();

    public DbSet<EmailVerificationToken> EmailVerificationTokens => Set<EmailVerificationToken>();

    public DbSet<TotpRecoveryCode> TotpRecoveryCodes => Set<TotpRecoveryCode>();

    // --- Administration ---
    public DbSet<AdminAuditEntry> AdminAuditEntries => Set<AdminAuditEntry>();

    // --- Events ---
    public DbSet<Event> Events => Set<Event>();

    public DbSet<EventMember> EventMembers => Set<EventMember>();

    public DbSet<EventScheduleItem> EventScheduleItems => Set<EventScheduleItem>();

    public DbSet<ActivityEntry> ActivityEntries => Set<ActivityEntry>();

    // --- Shopping ---
    public DbSet<ShoppingItem> ShoppingItems => Set<ShoppingItem>();

    // --- Expenses ---
    public DbSet<Expense> Expenses => Set<Expense>();

    public DbSet<ExpenseParticipant> ExpenseParticipants => Set<ExpenseParticipant>();

    public DbSet<ExpenseRevision> ExpenseRevisions => Set<ExpenseRevision>();

    // --- Settlements ---
    public DbSet<Settlement> Settlements => Set<Settlement>();

    // --- Tasks ---
    public DbSet<EventTask> EventTasks => Set<EventTask>();

    // --- Polls ---
    public DbSet<Poll> Polls => Set<Poll>();

    public DbSet<PollOption> PollOptions => Set<PollOption>();

    public DbSet<PollVote> PollVotes => Set<PollVote>();

    // --- Messages ---
    public DbSet<Message> Messages => Set<Message>();

    public DbSet<MessageReaction> MessageReactions => Set<MessageReaction>();

    public DbSet<MessageMention> MessageMentions => Set<MessageMention>();

    public DbSet<PinFolder> PinFolders => Set<PinFolder>();

    public DbSet<PinnedMessage> PinnedMessages => Set<PinnedMessage>();

    public DbSet<MessageRead> MessageReads => Set<MessageRead>();

    // --- Notifications ---
    public DbSet<Notification> Notifications => Set<Notification>();

    public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();

    public DbSet<EventMuteSetting> EventMuteSettings => Set<EventMuteSetting>();

    public DbSet<PushDevice> PushDevices => Set<PushDevice>();

    // --- Technique ---
    public DbSet<Idempotency.IdempotencyRecord> IdempotencyRecords => Set<Idempotency.IdempotencyRecord>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);

        base.OnModelCreating(modelBuilder);

        modelBuilder.HasPostgresExtension("citext");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(PartyPlanDbContext).Assembly);

        // Nommage avant filtres : les filtres ne dépendent pas des noms de colonnes,
        // mais l'ordre reste explicite pour éviter toute surprise à la relecture.
        SnakeCaseNaming.Apply(modelBuilder);
        QueryFilterBuilder.ApplyGlobalFilters(modelBuilder, this);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        GuardAppendOnlyTables();
        StampIdentifiersAndTimestamps();

        return base.SaveChangesAsync(cancellationToken);
    }

    public override int SaveChanges()
    {
        GuardAppendOnlyTables();
        StampIdentifiersAndTimestamps();

        return base.SaveChanges();
    }

    /// <summary>
    /// Première barrière contre la réécriture de l'histoire. Échoue bruyamment plutôt
    /// que de renvoyer une erreur métier : une telle écriture ne peut venir que d'un
    /// défaut de code.
    /// </summary>
    private void GuardAppendOnlyTables()
    {
        foreach (var entry in ChangeTracker.Entries())
        {
            if (entry.State is not (EntityState.Modified or EntityState.Deleted))
            {
                continue;
            }

            if (AppendOnlyTypes.Contains(entry.Entity.GetType()))
            {
                throw new SharedKernel.Errors.ModuleBoundaryException(
                    $"La table de « {entry.Entity.GetType().Name} » est en ajout seul : " +
                    "ni modification ni suppression ne sont permises (RG-ADM-06, RG-FIL-02).");
            }
        }
    }

    private void StampIdentifiersAndTimestamps()
    {
        var now = clock.UtcNow;

        foreach (var entry in ChangeTracker.Entries())
        {
            if (entry.State == EntityState.Added)
            {
                AssignIdentifierIfEmpty(entry);

                if (entry.Entity is IAuditable created)
                {
                    created.CreatedAt = created.CreatedAt == default ? now : created.CreatedAt;
                    created.UpdatedAt = now;
                }
            }
            else if (entry.State == EntityState.Modified && entry.Entity is IAuditable updated)
            {
                updated.UpdatedAt = now;
            }
        }
    }

    /// <summary>
    /// Attribue un UUID v7 lorsque l'identifiant n'a pas été fixé par l'appelant (§7.1).
    /// Laisser la base générer la clé priverait le code appelant de l'identifiant avant
    /// l'enregistrement.
    /// </summary>
    private void AssignIdentifierIfEmpty(Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry entry)
    {
        var idProperty = entry.Properties.FirstOrDefault(p =>
            p.Metadata.Name == "Id" && p.Metadata.ClrType == typeof(Guid));

        if (idProperty is not null && (Guid)idProperty.CurrentValue! == Guid.Empty)
        {
            idProperty.CurrentValue = idGenerator.NewId();
        }
    }
}
