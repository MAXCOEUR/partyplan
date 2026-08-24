namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Modules.Users.Domain;

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(u => u.Id);

        // citext : les adresses sont comparées sans tenir compte de la casse, ce qui
        // évite deux comptes distincts pour « Max@x.fr » et « max@x.fr ».
        builder.Property(u => u.Email).HasColumnType("citext").HasMaxLength(320);
        builder.Property(u => u.DisplayName).HasMaxLength(120).IsRequired();
        builder.Property(u => u.PasswordHash).HasMaxLength(256);
        builder.Property(u => u.Locale).HasMaxLength(10).IsRequired();
        builder.Property(u => u.Timezone).HasMaxLength(64).IsRequired();
        builder.Property(u => u.AvatarUrl).HasMaxLength(512);
        builder.Property(u => u.GoogleSubject).HasMaxLength(256);
        builder.Property(u => u.AppleSubject).HasMaxLength(256);
        builder.Property(u => u.SuspensionReason).HasMaxLength(500);
        builder.Property(u => u.PlatformRole).HasConversion<string>().HasMaxLength(20).IsRequired();

        // Unicité restreinte aux comptes vivants : RG-USR-06 libère l'adresse d'un
        // compte supprimé pour une réinscription ultérieure.
        builder.HasIndex(u => u.Email)
            .IsUnique()
            .HasFilter("deleted_at IS NULL");

        builder.HasIndex(u => u.GoogleSubject).IsUnique();
        builder.HasIndex(u => u.AppleSubject).IsUnique();

        // Index partiel : les rôles plateforme sont rares, l'index reste minuscule.
        builder.HasIndex(u => u.PlatformRole)
            .HasFilter("platform_role <> 'User'");
    }
}

internal sealed class SessionConfiguration : IEntityTypeConfiguration<Session>
{
    public void Configure(EntityTypeBuilder<Session> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.RefreshTokenHash).HasMaxLength(128).IsRequired();
        builder.Property(s => s.DeviceLabel).HasMaxLength(120);
        builder.Property(s => s.UserAgent).HasMaxLength(400);

        builder.HasIndex(s => s.RefreshTokenHash).IsUnique();
        builder.HasIndex(s => new { s.UserId, s.RevokedAt });

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(s => s.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class GroupConfiguration : IEntityTypeConfiguration<Group>
{
    public void Configure(EntityTypeBuilder<Group> builder)
    {
        builder.HasKey(g => g.Id);
        builder.Property(g => g.Name).HasMaxLength(120).IsRequired();

        builder.HasMany(g => g.Members)
            .WithOne()
            .HasForeignKey(m => m.GroupId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(g => g.OwnerUserId);
    }
}

internal sealed class GroupMemberConfiguration : IEntityTypeConfiguration<GroupMember>
{
    public void Configure(EntityTypeBuilder<GroupMember> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.DisplayName).HasMaxLength(120).IsRequired();
        builder.Property(m => m.Email).HasColumnType("citext").HasMaxLength(320);

        builder.HasIndex(m => new { m.GroupId, m.UserId })
            .IsUnique()
            .HasFilter("user_id IS NOT NULL AND removed_at IS NULL");
    }
}
