namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.Logging;

/// <summary>
/// Choix de l'émetteur de notifications, une seule fois au démarrage.
/// <para>
/// Extrait de l'enregistrement des services afin d'être testable : la décision « avec ou
/// sans Firebase » est celle qui tient la règle 5, et elle mérite un test plutôt qu'une
/// relecture.
/// </para>
/// </summary>
public static class PushSenderFactory
{
    /// <summary>
    /// Renvoie la clé à utiliser, ou <c>null</c> pour rester sur la console.
    /// <para>
    /// Un problème est journalisé en avertissement, jamais levé : une clé cassée ne doit
    /// pas empêcher l'application de démarrer, elle doit la faire retomber sur la console
    /// en le disant.
    /// </para>
    /// </summary>
    public static ServiceAccountKey? CleUtilisable(string? chemin, ILogger logger)
    {
        ArgumentNullException.ThrowIfNull(logger);

        var cle = ServiceAccountKey.Lire(chemin, out var probleme);

        if (probleme is not null)
        {
            logger.LogWarning(
                "Clé Firebase inutilisable, les notifications seront journalisées : {Probleme}",
                probleme);
        }
        else if (cle is null)
        {
            logger.LogInformation(
                "Aucune clé Firebase configurée : les notifications sont journalisées (NF-DEV-04).");
        }

        return cle;
    }
}
