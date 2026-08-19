namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Shopping.Domain;

internal sealed class ShoppingItemConfiguration : IEntityTypeConfiguration<ShoppingItem>
{
    public void Configure(EntityTypeBuilder<ShoppingItem> builder)
    {
        builder.HasKey(i => i.Id);
        builder.Property(i => i.Name).HasMaxLength(200).IsRequired();
        builder.Property(i => i.Unit).HasMaxLength(30);
        builder.Property(i => i.Note).HasMaxLength(500);
        builder.Property(i => i.Category).HasConversion<string>().HasMaxLength(20).IsRequired();
        builder.Property(i => i.Quantity).HasColumnType("numeric(8,2)");
        builder.Property(i => i.PurchasedQuantity).HasColumnType("numeric(8,2)");

        // §6.1 : jamais de type flottant sur un montant.
        builder.Property(i => i.EstimatedPrice).HasColumnType("numeric(10,2)");
        builder.Property(i => i.ActualPrice).HasColumnType("numeric(10,2)");

        builder.HasIndex(i => new { i.EventId, i.Position });
        builder.HasIndex(i => i.AssignedMemberId);

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(i => i.EventId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<EventMember>()
            .WithMany()
            .HasForeignKey(i => i.AssignedMemberId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
