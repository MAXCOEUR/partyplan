namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Modules.Administration.Domain;

internal sealed class AdminAuditEntryConfiguration : IEntityTypeConfiguration<AdminAuditEntry>
{
    public void Configure(EntityTypeBuilder<AdminAuditEntry> builder)
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.ActorEmail).HasColumnType("citext").HasMaxLength(320).IsRequired();
        builder.Property(e => e.Action).HasMaxLength(80).IsRequired();
        builder.Property(e => e.Reason).HasMaxLength(500);
        builder.Property(e => e.Metadata).HasColumnType("jsonb");

        builder.HasIndex(e => e.CreatedAt).IsDescending();
        builder.HasIndex(e => e.TargetUserId);
        builder.HasIndex(e => e.ActorUserId);

        // Aucune clé étrangère vers users : le journal doit survivre à la suppression
        // du compte auteur comme à celle du compte cible (RG-ADM-06).
    }
}
