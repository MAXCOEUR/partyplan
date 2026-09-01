namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Destinations ouvertes au clic sur une notification.
/// <para>
/// Rassemblées ici plutôt qu'interpolées dans chaque module, parce qu'elles ne sont pas
/// des chaînes libres : ce sont des routes de l'application Flutter, écrites dans un
/// dépôt que le compilateur C# ne voit pas. Le module Courses envoyait
/// <c>/events/{id}/courses</c> alors qu'aucune route ne l'accueillait, et le lien
/// tombait sur « cet événement n'existe pas ». Rien ne pouvait le signaler.
/// </para>
/// <para>
/// <see cref="Motifs"/> est la liste que l'application vérifie de son côté, par
/// <c>docs/api/destinations-notification.json</c>. Ajouter une destination sans ajouter
/// la route fait échouer le test de l'application.
/// </para>
/// </summary>
public static class DestinationsNotification
{
    /// <summary>Tableau de bord de la soirée.</summary>
    public static string Soiree(Guid eventId) => $"/events/{eventId}";

    /// <summary>Onglet des courses.</summary>
    public static string Courses(Guid eventId) => $"/events/{eventId}/courses";

    /// <summary>Onglet des dépenses.</summary>
    public static string Depenses(Guid eventId) => $"/events/{eventId}/depenses";

    /// <summary>Onglet de la discussion.</summary>
    public static string Discussion(Guid eventId) => $"/events/{eventId}/discussion";

    /// <summary>Écran des remboursements.</summary>
    public static string Reglements(Guid eventId) => $"/events/{eventId}/reglements";

    /// <summary>Liste des invités.</summary>
    public static string Invites(Guid eventId) => $"/events/{eventId}/invites";

    /// <summary>Écran des sondages.</summary>
    public static string Sondages(Guid eventId) => $"/events/{eventId}/sondages";

    /// <summary>
    /// Les destinations sous leur forme abstraite, telles que l'application les déclare.
    /// L'ordre n'a pas de sens ; l'ensemble, si.
    /// </summary>
    public static IReadOnlyList<string> Motifs { get; } =
    [
        "/events/{eventId}",
        "/events/{eventId}/courses",
        "/events/{eventId}/depenses",
        "/events/{eventId}/discussion",
        "/events/{eventId}/reglements",
        "/events/{eventId}/invites",
        "/events/{eventId}/sondages",
    ];
}
