namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Envoi de courriel transactionnel. Implémenté par l'Infrastructure.
/// <para>
/// En développement, la destination est un serveur local de capture : aucun message ne
/// part vers une adresse réelle (NF-DEV-03).
/// </para>
/// </summary>
public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken);
}

public sealed record EmailMessage(string To, string Subject, string TextBody, string? HtmlBody = null);
