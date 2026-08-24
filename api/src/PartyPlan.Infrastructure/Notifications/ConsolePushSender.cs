namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

public sealed class PushOptions
{
    public const string SectionName = "Push";

    /// <summary>
    /// Chemin du fichier de clé de compte de service Firebase. Vide en développement :
    /// les notifications sont alors journalisées (NF-DEV-04).
    /// <para>
    /// Un chemin et non le contenu JSON : le déploiement se fait sur un NAS sans fichier
    /// « .env », en remplaçant les valeurs dans le compose. Y coller 2 300 caractères
    /// contenant une clé privée PEM est fonctionnel mais piégeux — une virgule mal
    /// échappée et le conteneur ne démarre plus, sans que rien ne l'explique.
    /// </para>
    /// </summary>
    public string? FirebaseServiceAccountPath { get; set; }
}

/// <summary>
/// Émetteur de notifications de développement.
/// <para>
/// Journalise au lieu d'envoyer. C'est l'exigence NF-DEV-04, et non un bouchon
/// provisoire : le développement doit se faire sans compte Firebase, et le contenu des
/// notifications doit rester lisible pour être vérifié.
/// </para>
/// <para>
/// L'implémentation Firebase la remplacera au lot 1.11, derrière le même contrat. Le
/// code appelant n'aura pas à changer.
/// </para>
/// </summary>
public sealed class ConsolePushSender(
    ILogger<ConsolePushSender> logger) : IPushSender
{
    /// <summary>
    /// Toujours faux : cet émetteur n'envoie rien, par construction. Une clé configurée
    /// donne <c>FirebasePushSender</c>, choisi au démarrage.
    /// </summary>
    public bool IsConfigured => false;

    public Task SendAsync(PushMessage message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);

        logger.LogInformation(
            "Notification poussée (non envoyée, aucune clé configurée) — "
            + "appareil {Appareil}, titre « {Titre} », corps « {Corps} », lien {Lien}",
            Tronquer(message.DeviceToken),
            message.Title,
            message.Body,
            message.DeepLink ?? "aucun");

        return Task.CompletedTask;
    }

    /// <summary>
    /// Le jeton d'appareil est tronqué : entier, il encombre le journal sans rien
    /// apprendre, et c'est une donnée d'identification (NF-SEC-03).
    /// </summary>
    private static string Tronquer(string jeton) =>
        jeton.Length <= 12 ? jeton : $"{jeton[..8]}…";
}
