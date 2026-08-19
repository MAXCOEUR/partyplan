namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Modules.Events.Domain;

internal sealed class EventConfiguration : IEntityTypeConfiguration<Event>
{
    public void Configure(EntityTypeBuilder<Event> builder)
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Name).HasMaxLength(120).IsRequired();
        builder.Property(e => e.Description).HasMaxLength(4000);
        builder.Property(e => e.Address).HasMaxLength(300);
        builder.Property(e => e.Latitude).HasColumnType("numeric(9,6)");
        builder.Property(e => e.Longitude).HasColumnType("numeric(9,6)");
        builder.Property(e => e.CoverImageUrl).HasMaxLength(512);
        builder.Property(e => e.InviteToken).HasMaxLength(64).IsRequired();
        builder.Property(e => e.ShortCode).HasMaxLength(16).IsRequired();

        builder.HasIndex(e => e.InviteToken).IsUnique();

        // Unicité du code court restreinte aux événements vivants : RG-INV-02 n'exige
        // l'unicité que parmi les événements non archivés, ce qui laisse le stock de
        // codes se recycler.
        builder.HasIndex(e => e.ShortCode)
            .IsUnique()
            .HasFilter("archived_at IS NULL AND deleted_at IS NULL");

        builder.HasIndex(e => e.StartsAt);

        builder.HasMany(e => e.Members)
            .WithOne()
            .HasForeignKey(m => m.EventId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class EventMemberConfiguration : IEntityTypeConfiguration<EventMember>
{
    public void Configure(EntityTypeBuilder<EventMember> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.DisplayName).HasMaxLength(120).IsRequired();
        builder.Property(m => m.Status).HasConversion<string>().HasMaxLength(20).IsRequired();
        builder.Property(m => m.Role).HasConversion<string>().HasMaxLength(20).IsRequired();
        builder.Property(m => m.GuestSessionHash).HasMaxLength(128);

        // Un compte ne peut être membre qu'une fois d'un même événement. Le filtre
        // exclut les invités sans compte, dont user_id est nul.
        builder.HasIndex(m => new { m.EventId, m.UserId })
            .IsUnique()
            .HasFilter("user_id IS NOT NULL");

        // Un seul propriétaire par événement (RG-ROLE-01).
        builder.HasIndex(m => m.EventId)
            .IsUnique()
            .HasFilter("role = 'Owner' AND removed_at IS NULL")
            .HasDatabaseName("ix_event_members_single_owner");

        builder.HasIndex(m => m.UserId);
        builder.HasIndex(m => m.GuestSessionHash);
    }
}

internal sealed class EventScheduleItemConfiguration : IEntityTypeConfiguration<EventScheduleItem>
{
    public void Configure(EntityTypeBuilder<EventScheduleItem> builder)
    {
        builder.HasKey(i => i.Id);
        builder.Property(i => i.Label).HasMaxLength(200).IsRequired();
        builder.Property(i => i.Location).HasMaxLength(300);
        builder.Property(i => i.Note).HasMaxLength(1000);

        builder.HasIndex(i => new { i.EventId, i.StartsAt });

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(i => i.EventId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class ActivityEntryConfiguration : IEntityTypeConfiguration<ActivityEntry>
{
    public void Configure(EntityTypeBuilder<ActivityEntry> builder)
    {
        builder.HasKey(a => a.Id);
        builder.Property(a => a.ActorName).HasMaxLength(120).IsRequired();
        builder.Property(a => a.Kind).HasMaxLength(60).IsRequired();
        builder.Property(a => a.Payload).HasColumnType("jsonb");

        // Pagination par curseur descendant : l'index porte l'ordre de lecture.
        builder.HasIndex(a => new { a.EventId, a.CreatedAt }).IsDescending(false, true);

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(a => a.EventId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
