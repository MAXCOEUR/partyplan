namespace PartyPlan.Modules.Notifications.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Notifications.Domain;

public interface INotificationsDbContext
{
    DbSet<Notification> Notifications { get; }

    DbSet<NotificationPreference> NotificationPreferences { get; }

    DbSet<EventMuteSetting> EventMuteSettings { get; }

    DbSet<PushDevice> PushDevices { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
