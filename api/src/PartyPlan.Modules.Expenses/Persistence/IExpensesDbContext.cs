namespace PartyPlan.Modules.Expenses.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Expenses.Domain;

public interface IExpensesDbContext
{
    DbSet<Expense> Expenses { get; }

    DbSet<ExpenseParticipant> ExpenseParticipants { get; }

    DbSet<ExpenseRevision> ExpenseRevisions { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
