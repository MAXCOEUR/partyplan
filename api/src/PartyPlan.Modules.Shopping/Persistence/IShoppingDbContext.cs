namespace PartyPlan.Modules.Shopping.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Shopping.Domain;

public interface IShoppingDbContext
{
    DbSet<ShoppingItem> ShoppingItems { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
