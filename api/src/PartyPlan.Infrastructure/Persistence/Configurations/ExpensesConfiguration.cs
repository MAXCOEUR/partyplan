namespace PartyPlan.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Expenses.Domain;

internal sealed class ExpenseConfiguration : IEntityTypeConfiguration<Expense>
{
    public void Configure(EntityTypeBuilder<Expense> builder)
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Label).HasMaxLength(200).IsRequired();
        builder.Property(e => e.Amount).HasColumnType("numeric(10,2)").IsRequired();
        builder.Property(e => e.ReceiptUrl).HasMaxLength(512);

        // Le plafond et la positivité sont vérifiés par la base, pas seulement par le
        // code : une écriture par un outil d'administration reste contrainte (RG-DEP-01).
        builder.ToTable(t => t.HasCheckConstraint(
            "ck_expenses_amount_range",
            $"amount > 0 AND amount <= {Expense.MaxAmount.ToString(System.Globalization.CultureInfo.InvariantCulture)}"));

        builder.HasIndex(e => new { e.EventId, e.SpentAt });
        builder.HasIndex(e => e.PaidByMemberId);

        builder.HasOne<Event>()
            .WithMany()
            .HasForeignKey(e => e.EventId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(e => e.Participants)
            .WithOne()
            .HasForeignKey(p => p.ExpenseId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(e => e.Revisions)
            .WithOne()
            .HasForeignKey(r => r.ExpenseId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class ExpenseParticipantConfiguration : IEntityTypeConfiguration<ExpenseParticipant>
{
    public void Configure(EntityTypeBuilder<ExpenseParticipant> builder)
    {
        builder.HasKey(p => new { p.ExpenseId, p.MemberId });

        builder.ToTable(t => t.HasCheckConstraint("ck_expense_participants_share", "share > 0"));

        builder.HasOne<EventMember>()
            .WithMany()
            .HasForeignKey(p => p.MemberId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class ExpenseRevisionConfiguration : IEntityTypeConfiguration<ExpenseRevision>
{
    public void Configure(EntityTypeBuilder<ExpenseRevision> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.PreviousAmount).HasColumnType("numeric(10,2)");
        builder.Property(r => r.PreviousParticipants).HasColumnType("jsonb").IsRequired();

        builder.HasIndex(r => new { r.ExpenseId, r.CreatedAt });
    }
}
