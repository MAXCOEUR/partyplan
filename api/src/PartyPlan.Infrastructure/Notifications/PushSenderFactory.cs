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
    /// Emplacement conventionnel de la clé dans le conteneur.
    /// <para>
    /// Le chemin du fichier à l'intérieur du conteneur est fixé par le montage du
    /// compose ; le redemander en configuration crée deux moitiés qu'il faut accorder à
    /// la main. Une clé montée sans chemin déclaré donnait une API muette, retombée sur
    /// la console sans que rien ne l'explique. Le connaître ici supprime la coordination.
    /// </para>
    /// </summary>
    public const string CheminConventionnel = "/run/secrets/firebase.json";

    /// <summary>
    /// Renvoie la clé à utiliser, ou <c>null</c> pour rester sur la console.
    /// <para>
    /// Un problème est journalisé en avertissement, jamais levé : une clé cassée ne doit
    /// pas empêcher l'application de démarrer, elle doit la faire retomber sur la console
    /// en le disant.
    /// </para>
    /// </summary>
    /// <param name="chemin">
    /// Chemin configuré. Vide, l'emplacement conventionnel est essayé : une instance qui
    /// monte sa clé au bon endroit n'a alors rien à déclarer.
    /// </param>
    /// <param name="logger">Journal de démarrage.</param>
    /// <param name="cheminConventionnel">Injecté pour les tests uniquement.</param>
    public static ServiceAccountKey? CleUtilisable(
        string? chemin,
        ILogger logger,
        string cheminConventionnel = CheminConventionnel)
    {
        ArgumentNullException.ThrowIfNull(logger);

        // Un chemin explicite l'emporte : une instance range sa clé où elle veut.
        var retenu = string.IsNullOrWhiteSpace(chemin) ? cheminConventionnel : chemin;

        // La convention est essayée en silence : son absence est le cas normal d'un
        // poste de développement, où aucun fichier n'est monté (règle 5).
        if (string.IsNullOrWhiteSpace(chemin) && !File.Exists(cheminConventionnel))
        {
            logger.LogInformation(
                "Aucune clé Firebase configurée : les notifications sont journalisées (NF-DEV-04).");
            return null;
        }

        var cle = ServiceAccountKey.Lire(retenu, out var probleme);

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
        else
        {
            // Le succès s'écrit, et nomme le projet servi. Sans cette ligne, « clé
            // chargée » et « configuration jamais lue » laissent la même trace dans le
            // journal — aucune — et une instance distante devient indiagnosticable.
            logger.LogInformation(
                "Notifications poussées actives : projet Firebase {ProjectId}, compte de service {Compte}.",
                cle.ProjectId,
                cle.ClientEmail);
        }

        return cle;
    }
}
