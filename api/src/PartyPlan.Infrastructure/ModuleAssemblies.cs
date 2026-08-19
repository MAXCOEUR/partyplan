namespace PartyPlan.Infrastructure;

using System.Reflection;

/// <summary>
/// Assemblages des modules, énumérés explicitement. Une découverte par balayage du
/// répertoire ou du domaine d'application manquerait les modules non encore chargés :
/// l'énumération explicite échoue à la compilation si un module est retiré, ce qui est
/// le comportement souhaité.
/// </summary>
public static class ModuleAssemblies
{
    public static IReadOnlyList<Assembly> All { get; } =
    [
        typeof(Modules.Auth.AuthModule).Assembly,
        typeof(Modules.Users.UsersModule).Assembly,
        typeof(Modules.Events.EventsModule).Assembly,
        typeof(Modules.Shopping.ShoppingModule).Assembly,
        typeof(Modules.Expenses.ExpensesModule).Assembly,
        typeof(Modules.Settlements.SettlementsModule).Assembly,
        typeof(Modules.Tasks.TasksModule).Assembly,
        typeof(Modules.Polls.PollsModule).Assembly,
        typeof(Modules.Messages.MessagesModule).Assembly,
        typeof(Modules.Notifications.NotificationsModule).Assembly,
        typeof(Modules.Administration.AdministrationModule).Assembly,
    ];
}
