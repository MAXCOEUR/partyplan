namespace PartyPlan.Infrastructure.Notifications;

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Envoi réel des notifications, par FCM HTTP v1.
/// <para>
/// Scoped : la mise au rebut d'un jeton passe par <see cref="IPushDeviceRegistry"/>, lui
/// aussi scoped. Le cache du jeton d'accès est isolé dans <see cref="GoogleAccessTokens"/>,
/// singleton, sans quoi il serait vidé à chaque requête.
/// </para>
/// </summary>
public sealed class FirebasePushSender(
    ServiceAccountKey cle,
    GoogleAccessTokens jetons,
    HttpClient http,
    IPushDeviceRegistry appareils,
    ILogger<FirebasePushSender> logger) : IPushSender
{
    public bool IsConfigured => true;

    public async Task SendAsync(PushMessage message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);

        try
        {
            var acces = await jetons.ObtenirAsync(cle, cancellationToken).ConfigureAwait(false);

            if (acces is null)
            {
                // Déjà journalisé par GoogleAccessTokens : ne pas doubler le bruit.
                return;
            }

            using var requete = new HttpRequestMessage(
                HttpMethod.Post,
                new Uri($"https://fcm.googleapis.com/v1/projects/{cle.ProjectId}/messages:send"))
            {
                Headers = { Authorization = new("Bearer", acces) },
                Content = JsonContent.Create(Corps(message)),
            };

            using var reponse = await http
                .SendAsync(requete, cancellationToken)
                .ConfigureAwait(false);

            if (reponse.IsSuccessStatusCode)
            {
                return;
            }

            await TraiterEchecAsync(reponse, message, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception erreur) when (erreur is not OperationCanceledException)
        {
            // Aucune exception ne franchit cette frontière : une notification perdue ne
            // doit jamais faire échouer la dépense, l'achat ou l'invitation qui l'a
            // déclenchée.
            logger.LogError(
                erreur,
                "Notification non envoyée à l'appareil {Appareil}.",
                Tronquer(message.DeviceToken));
        }
    }

    /// <summary>
    /// Corps du message. Le lien profond et la clé de groupe voyagent dans <c>data</c> et
    /// non dans <c>notification</c> : c'est le client qui décide quoi ouvrir et comment
    /// empiler, le système d'exploitation n'a pas à connaître nos routes.
    /// </summary>
    private static object Corps(PushMessage message)
    {
        var donnees = DonneesMessage(message);

        return donnees is null
            ? new
            {
                message = new
                {
                    token = message.DeviceToken,
                    notification = new { title = message.Title, body = message.Body },
                },
            }
            : new
            {
                message = new
                {
                    token = message.DeviceToken,
                    notification = new { title = message.Title, body = message.Body },
                    data = donnees,
                },
            };
    }

    /// <summary>
    /// Champ <c>data</c>, ou <c>null</c> lorsqu'il n'y a rien à y mettre : un champ vide
    /// n'a pas de sens à envoyer.
    /// </summary>
    private static Dictionary<string, string>? DonneesMessage(PushMessage message)
    {
        if (message.DeepLink is null
            && message.GroupKey is null
            && message.Category is null
            && message.EventId is null)
        {
            return null;
        }

        var donnees = new Dictionary<string, string>();

        if (message.DeepLink is not null)
        {
            donnees["deepLink"] = message.DeepLink;
        }

        if (message.Category is not null)
        {
            // Lue par l'application au premier plan, pour savoir si l'écran ouvert montre
            // déjà ce que la notification annonce.
            donnees["categorie"] = message.Category;
        }

        if (message.EventId is not null)
        {
            donnees["evenement"] = message.EventId;
        }

        if (message.GroupKey is not null)
        {
            // Empilement sur l'appareil, en remplacement du plafond serveur retiré le
            // 30/08/2026. Android range les notifications d'une même clé sous un seul
            // bandeau ; le Web remplace au lieu d'empiler, ce qui est accepté.
            donnees["groupe"] = message.GroupKey;
        }

        return donnees;
    }

    private async Task TraiterEchecAsync(
        HttpResponseMessage reponse,
        PushMessage message,
        CancellationToken cancellationToken)
    {
        var brut = await reponse.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        var code = CodeErreur(brut);

        // UNREGISTERED : application désinstallée ou données effacées. INVALID_ARGUMENT sur
        // ce chemin : jeton malformé. Dans les deux cas le jeton ne redeviendra jamais
        // valide, et le garder ferait échouer chaque envoi jusqu'à la fin des temps.
        if (code is "UNREGISTERED" or "INVALID_ARGUMENT")
        {
            logger.LogInformation(
                "Appareil {Appareil} mis au rebut par FCM : {Code}.",
                Tronquer(message.DeviceToken),
                code);

            await appareils
                .DisableAsync(message.DeviceToken, $"fcm:{code}", cancellationToken)
                .ConfigureAwait(false);

            return;
        }

        // Panne passagère : journalisée, sans rejeu. Le rejeu appartient à l'ordonnanceur
        // du lot 1.11, qui n'existe pas encore.
        logger.LogWarning(
            "FCM refuse la notification pour {Appareil} : {Statut} {Code}.",
            Tronquer(message.DeviceToken),
            (int)reponse.StatusCode,
            code ?? "sans code");
    }

    /// <summary>Code d'erreur FCM, cherché dans <c>error.details[].errorCode</c>.</summary>
    private static string? CodeErreur(string corps)
    {
        try
        {
            using var document = JsonDocument.Parse(corps);

            if (!document.RootElement.TryGetProperty("error", out var erreur))
            {
                return null;
            }

            if (erreur.TryGetProperty("details", out var details)
                && details.ValueKind == JsonValueKind.Array)
            {
                foreach (var detail in details.EnumerateArray())
                {
                    if (detail.TryGetProperty("errorCode", out var code)
                        && code.ValueKind == JsonValueKind.String)
                    {
                        return code.GetString();
                    }
                }
            }

            return erreur.TryGetProperty("status", out var statut)
                   && statut.ValueKind == JsonValueKind.String
                ? statut.GetString()
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>
    /// Le jeton d'appareil est tronqué : entier, il encombre le journal sans rien
    /// apprendre, et c'est une donnée d'identification (NF-SEC-03).
    /// </summary>
    private static string Tronquer(string jeton) =>
        jeton.Length <= 12 ? jeton : $"{jeton[..8]}…";
}
