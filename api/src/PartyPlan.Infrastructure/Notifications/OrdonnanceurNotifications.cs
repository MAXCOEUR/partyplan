namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>Réglages de l'ordonnanceur de notifications.</summary>
public sealed class OrdonnanceurOptions
{
    public const string SectionName = "Notifications:Ordonnanceur";

    /// <summary>
    /// Éteint l'ordonnanceur. Les tests d'intégration le coupent : une passe déclenchée
    /// sous leurs pieds enverrait des notifications qu'ils n'ont pas demandées.
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Intervalle entre deux passes. Une minute : la granularité la plus fine du lot est
    /// le rappel « 2 h avant », et personne ne remarque soixante secondes. Une cadence à
    /// la seconde multiplierait par soixante les requêtes pour la même valeur d'usage.
    /// </summary>
    public TimeSpan Cadence { get; set; } = TimeSpan.FromMinutes(1);

    /// <summary>Jusqu'où regarder devant. Le rappel le plus lointain est J-3.</summary>
    public TimeSpan Horizon { get; set; } = TimeSpan.FromDays(4);

    /// <summary>
    /// Jusqu'où regarder derrière. <c>EF-NOT-06</c> notifie le lendemain de la fin.
    /// </summary>
    public TimeSpan Retard { get; set; } = TimeSpan.FromDays(2);
}

/// <summary>
/// Ordonnanceur des notifications (§5.12).
/// <para>
/// Deux passes à chaque réveil : <b>planifier</b>, en demandant à chaque module de
/// calculer ses rappels, puis <b>envoyer</b> ce qui est dû. La séparation est utile :
/// la planification est idempotente et rejouable, l'envoi ne l'est pas.
/// </para>
/// <para>
/// <b>Une seule instance</b> (RG-RT-04). La clé de déduplication protège la
/// planification, pas l'envoi : deux instances enverraient tout en double. C'est le
/// second motif, après le hub SignalR, qui interdit d'ajouter une instance sans ADR.
/// </para>
/// </summary>
public sealed class OrdonnanceurNotifications(
    IServiceScopeFactory portees,
    IClock clock,
    IOptions<OrdonnanceurOptions> options,
    ILogger<OrdonnanceurNotifications> logger) : BackgroundService
{
    private readonly OrdonnanceurOptions _options = options.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.Enabled)
        {
            logger.LogInformation(
                "Ordonnanceur de notifications éteint par configuration.");
            return;
        }

        logger.LogInformation(
            "Ordonnanceur de notifications démarré, cadence {Cadence}.",
            _options.Cadence);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await PasseAsync(clock.UtcNow, stoppingToken).ConfigureAwait(false);
            }
            catch (Exception erreur) when (erreur is not OperationCanceledException)
            {
                // Une passe qui échoue ne doit pas arrêter la boucle : le calcul est
                // idempotent, la suivante reprendra là où celle-ci s'est interrompue.
                logger.LogError(erreur, "Passe de l'ordonnanceur interrompue.");
            }

            try
            {
                await Task.Delay(_options.Cadence, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
    }

    /// <summary>
    /// Une passe complète, à un instant donné.
    /// <para>
    /// L'instant est un paramètre et non une lecture de l'horloge : un rappel « J-3 » ne
    /// se teste pas en attendant trois jours, et rendre l'horloge mutable pour toute
    /// l'application serait un prix bien plus lourd que ce paramètre.
    /// </para>
    /// </summary>
    public async Task PasseAsync(DateTimeOffset maintenant, CancellationToken cancellationToken)
    {
        using var portee = portees.CreateScope();
        var fournisseur = portee.ServiceProvider;

        var evenements = await fournisseur.GetRequiredService<IEvenementsAVenir>()
            .ListerAsync(maintenant, _options.Horizon, _options.Retard, cancellationToken)
            .ConfigureAwait(false);

        if (evenements.Count == 0)
        {
            return;
        }

        var planificateurs = fournisseur.GetServices<IPlanificateurRappels>().ToList();
        var scope = fournisseur.GetRequiredService<IEventScope>();
        var db = fournisseur.GetRequiredService<Persistence.PartyPlanDbContext>();

        foreach (var evenement in evenements)
        {
            // Le périmètre est ouvert événement par événement : le garde de
            // cloisonnement reste actif, borné à cette seule soirée. Le contourner par
            // IgnoreQueryFilters ferait de l'ordonnanceur le seul code du projet à lire
            // toutes les soirées à la fois — exactement ce que RG-SEC-01 interdit.
            using var acces = scope.AllowTemporarily(evenement.EventId);

            foreach (var planificateur in planificateurs)
            {
                try
                {
                    await planificateur
                        .PlanifierAsync(evenement, maintenant, cancellationToken)
                        .ConfigureAwait(false);
                }
                catch (Exception erreur) when (erreur is not OperationCanceledException)
                {
                    // Journalisée et non propagée : un planificateur en panne ne doit pas
                    // priver les autres de leur tour, et la passe suivante réessaiera.
                    logger.LogError(
                        erreur,
                        "Planificateur {Planificateur} en échec sur l'événement {Evenement}.",
                        planificateur.GetType().Name,
                        evenement.EventId);
                }
            }
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // L'envoi vient après la planification, et dans la même passe : un rappel calculé
        // à l'instant est dû à l'instant, et attendre le réveil suivant lui ferait perdre
        // une minute pour rien.
        await fournisseur.GetRequiredService<IEnvoiNotifications>()
            .EnvoyerLesDuesAsync(maintenant, cancellationToken)
            .ConfigureAwait(false);
    }
}
