namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Envoi d'une notification poussée. Implémenté par l'Infrastructure.
/// <para>
/// En l'absence de clé configurée, l'implémentation journalise en console et renvoie un
/// succès : une action métier ne doit jamais échouer parce qu'une notification n'a pas
/// pu partir (NF-DEV-04). Perdre l'avis vaut mieux que perdre la dépense qui l'a
/// déclenché.
/// </para>
/// </summary>
public interface IPushSender
{
    /// <summary>Vrai lorsqu'un fournisseur est réellement configuré.</summary>
    bool IsConfigured { get; }

    Task SendAsync(PushMessage message, CancellationToken cancellationToken);
}

/// <summary>Notification poussée destinée à un appareil.</summary>
public sealed record PushMessage(
    string DeviceToken,
    string Title,
    string Body,
    string? DeepLink = null);
