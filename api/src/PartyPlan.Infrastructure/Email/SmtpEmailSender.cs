namespace PartyPlan.Infrastructure.Email;

using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MimeKit;
using PartyPlan.SharedKernel.Contracts;

public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    public string Host { get; set; } = string.Empty;

    public int Port { get; set; } = 587;

    public string? User { get; set; }

    public string? Password { get; set; }

    public string From { get; set; } = "PartyPlan <ne-pas-repondre@partyplan.local>";

    /// <summary>
    /// Chiffrement du transport. Désactivé en développement : le serveur de capture
    /// local n'en propose pas, et l'exiger empêcherait de développer hors ligne.
    /// </summary>
    public bool UseStartTls { get; set; } = true;
}

/// <summary>
/// Envoi par SMTP.
/// <para>
/// En développement, la destination est Mailpit : aucun message ne part vers une adresse
/// réelle (NF-DEV-03). Un échec d'envoi est journalisé mais ne fait pas échouer
/// l'opération métier : une inscription ne doit pas être perdue parce que le serveur de
/// courriel est momentanément indisponible. Le lien peut toujours être redemandé.
/// </para>
/// </summary>
public sealed class SmtpEmailSender(
    IOptions<SmtpOptions> options,
    ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);

        var configuration = options.Value;

        if (string.IsNullOrWhiteSpace(configuration.Host))
        {
            // Sans serveur configuré, le contenu est journalisé afin que le
            // développement reste possible sans aucun service externe (NF-DEV-02).
            logger.LogWarning(
                "Aucun serveur SMTP configuré : courriel non envoyé à {Destinataire} — {Sujet}",
                message.To,
                message.Subject);
            return;
        }

        var courriel = new MimeMessage();
        courriel.From.Add(MailboxAddress.Parse(configuration.From));
        courriel.To.Add(MailboxAddress.Parse(message.To));
        courriel.Subject = message.Subject;
        courriel.Body = new BodyBuilder
        {
            TextBody = message.TextBody,
            HtmlBody = message.HtmlBody,
        }.ToMessageBody();

        try
        {
            using var client = new SmtpClient();

            await client.ConnectAsync(
                    configuration.Host,
                    configuration.Port,
                    configuration.UseStartTls ? SecureSocketOptions.StartTls : SecureSocketOptions.None,
                    cancellationToken)
                .ConfigureAwait(false);

            if (!string.IsNullOrWhiteSpace(configuration.User))
            {
                await client.AuthenticateAsync(
                        configuration.User,
                        configuration.Password ?? string.Empty,
                        cancellationToken)
                    .ConfigureAwait(false);
            }

            await client.SendAsync(courriel, cancellationToken).ConfigureAwait(false);
            await client.DisconnectAsync(true, cancellationToken).ConfigureAwait(false);

            logger.LogInformation("Courriel envoyé à {Destinataire} — {Sujet}", message.To, message.Subject);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Volontairement non propagé : perdre une inscription parce que le serveur
            // de courriel est indisponible serait un préjudice plus grave que l'absence
            // du message, qui peut être redemandé.
            logger.LogError(
                exception,
                "Échec d'envoi du courriel à {Destinataire} — {Sujet}",
                message.To,
                message.Subject);
        }
    }
}
