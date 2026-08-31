namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

/// <summary>
/// La clé de compte de service, lue une seule fois.
/// <para>
/// Singleton, et résolue au démarrage. Elle était auparavant relue à chaque portée : le
/// fichier était rouvert et la clé RSA reconstruite à chaque passe d'envoi, c'est-à-dire
/// toutes les minutes, et le verdict n'apparaissait au journal qu'à la première
/// notification — noyé au milieu de l'exploitation plutôt qu'au démarrage, là où on le
/// cherche.
/// </para>
/// </summary>
public sealed class CleFirebase
{
    public CleFirebase(IOptions<PushOptions> options, ILogger<CleFirebase> logger)
    {
        ArgumentNullException.ThrowIfNull(options);

        Cle = PushSenderFactory.CleUtilisable(
            options.Value.FirebaseServiceAccountPath,
            logger);
    }

    /// <summary>La clé, ou <c>null</c> lorsque les notifications restent en console.</summary>
    public ServiceAccountKey? Cle { get; }
}
