namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PartyPlan.SharedKernel.Contracts;

public sealed class PushOptions
{
    public const string SectionName = "Push";

    /// <summary>
    /// Contenu JSON du compte de service Firebase, sur une seule ligne. Vide en
    /// développement : les notifications sont alors journalisées (NF-DEV-04).
    /// </summary>
    public string? FirebaseServiceAccountJson { get; set; }
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
    IOptions<PushOptions> options,
    ILogger<ConsolePushSender> logger) : IPushSender
{
    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.FirebaseServiceAccountJson);

    public Task SendAsync(PushMessage message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);

        if (IsConfigured)
        {
            // Une clé est présente mais aucune implémentation ne la consomme encore :
            // le signaler plutôt que de laisser croire à un envoi.
            logger.LogWarning(
                "Une clé Firebase est configurée mais l'émetteur réel arrive au lot 1.11. "
                + "Notification non envoyée : {Titre}",
                message.Title);

            return Task.CompletedTask;
        }

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
