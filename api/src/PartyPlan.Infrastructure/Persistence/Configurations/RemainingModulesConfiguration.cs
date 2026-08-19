namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Infrastructure.Idempotency;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Messages.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Polls.Domain;
using PartyPlan.Modules.Settlements.Domain;
using PartyPlan.Modules.Tasks.Domain;
using PartyPlan.Modules.Users.Domain;

internal sealed class SettlementConfiguration : IEntityTypeConfiguration<Settlement>
{
    public void Configure(EntityTypeBuilder<Settlement> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Amount).HasColumnType("numeric(10,2)").IsRequired();

        builder.ToTable(t => t.HasCheckConstraint("ck_settlements_amount_positive", "amount > 0"));

        // Un remboursement de soi vers soi n'a pas de sens et fausserait les soldes.
        builder.ToTable(t => t.HasCheckConstraint(
            "ck_settlements_distinct_members",
            "from_member_id <> to_member_id"));

        builder.HasIndex(s => new { s.EventId, s.SettledAt });

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(s => s.EventId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<EventMember>()
            .WithMany()
            .HasForeignKey(s => s.FromMemberId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<EventMember>()
            .WithMany()
            .HasForeignKey(s => s.ToMemberId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class EventTaskConfiguration : IEntityTypeConfiguration<EventTask>
{
    public void Configure(EntityTypeBuilder<EventTask> builder)
    {
        builder.ToTable("tasks");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Label).HasMaxLength(200).IsRequired();

        builder.HasIndex(t => new { t.EventId, t.Position });

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(t => t.EventId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class PollConfiguration : IEntityTypeConfiguration<Poll>
{
    public void Configure(EntityTypeBuilder<Poll> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Question).HasMaxLength(300).IsRequired();

        builder.HasIndex(p => p.EventId);

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(p => p.EventId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.Options)
            .WithOne()
            .HasForeignKey(o => o.PollId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class PollOptionConfiguration : IEntityTypeConfiguration<PollOption>
{
    public void Configure(EntityTypeBuilder<PollOption> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Label).HasMaxLength(200).IsRequired();
        builder.HasIndex(o => new { o.PollId, o.Position });
    }
}

internal sealed class PollVoteConfiguration : IEntityTypeConfiguration<PollVote>
{
    public void Configure(EntityTypeBuilder<PollVote> builder)
    {
        builder.HasKey(v => v.Id);

        // Un vote unique par membre et par sondage, tant que le choix multiple n'est
        // pas ouvert (EF-SDG-01). L'index porte la règle : changer son vote met à jour
        // la ligne existante plutôt que d'en créer une seconde (EF-SDG-02).
        builder.HasIndex(v => new { v.PollId, v.MemberId }).IsUnique();

        builder.HasOne<PollOption>()
            .WithMany(o => o.Votes)
            .HasForeignKey(v => v.OptionId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Body).HasMaxLength(4000);
        builder.Property(m => m.AttachmentUrl).HasMaxLength(512);

        builder.HasIndex(m => new { m.EventId, m.CreatedAt }).IsDescending(false, true);

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(m => m.EventId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(m => m.Reactions)
            .WithOne()
            .HasForeignKey(r => r.MessageId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class MessageReactionConfiguration : IEntityTypeConfiguration<MessageReaction>
{
    public void Configure(EntityTypeBuilder<MessageReaction> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Emoji).HasMaxLength(16).IsRequired();
        builder.HasIndex(r => new { r.MessageId, r.MemberId, r.Emoji }).IsUnique();
    }
}

internal sealed class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.HasKey(n => n.Id);
        builder.Property(n => n.Category).HasMaxLength(60).IsRequired();
        builder.Property(n => n.Title).HasMaxLength(200).IsRequired();
        builder.Property(n => n.Body).HasMaxLength(1000).IsRequired();
        builder.Property(n => n.DeepLink).HasMaxLength(300);

        // File d'envoi : l'ordonnanceur lit les notifications dues et non encore parties.
        builder.HasIndex(n => new { n.ScheduledFor, n.SentAt });
        builder.HasIndex(n => new { n.UserId, n.ReadAt });
    }
}

internal sealed class NotificationPreferenceConfiguration : IEntityTypeConfiguration<NotificationPreference>
{
    public void Configure(EntityTypeBuilder<NotificationPreference> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Category).HasMaxLength(60).IsRequired();
        builder.HasIndex(p => new { p.UserId, p.Category }).IsUnique();

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(p => p.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class EventMuteSettingConfiguration : IEntityTypeConfiguration<EventMuteSetting>
{
    public void Configure(EntityTypeBuilder<EventMuteSetting> builder)
    {
        builder.HasKey(m => m.Id);
        builder.HasIndex(m => new { m.UserId, m.EventId }).IsUnique();
    }
}

internal sealed class PushDeviceConfiguration : IEntityTypeConfiguration<PushDevice>
{
    public void Configure(EntityTypeBuilder<PushDevice> builder)
    {
        builder.HasKey(d => d.Id);
        builder.Property(d => d.Token).HasMaxLength(512).IsRequired();
        builder.Property(d => d.Platform).HasMaxLength(20).IsRequired();
        builder.HasIndex(d => d.Token).IsUnique();
        builder.HasIndex(d => d.UserId);

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(d => d.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class IdempotencyRecordConfiguration : IEntityTypeConfiguration<IdempotencyRecord>
{
    public void Configure(EntityTypeBuilder<IdempotencyRecord> builder)
    {
        builder.ToTable("idempotency_keys");
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Key).HasMaxLength(128).IsRequired();
        builder.Property(r => r.Endpoint).HasMaxLength(200).IsRequired();
        builder.Property(r => r.RequestHash).HasMaxLength(128).IsRequired();
        builder.Property(r => r.ResponseBody).HasColumnType("jsonb");

        // Une clé est propre à un appelant et à un endpoint : deux utilisateurs
        // peuvent réutiliser la même valeur sans se gêner.
        builder.HasIndex(r => new { r.Key, r.UserId, r.Endpoint }).IsUnique();
        builder.HasIndex(r => r.ExpiresAt);
    }
}
