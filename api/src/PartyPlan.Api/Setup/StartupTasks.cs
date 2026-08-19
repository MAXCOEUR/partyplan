namespace PartyPlan.Api.Setup;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Users.Application;

/// <summary>
/// Amorçage du premier administrateur au démarrage (EF-ADM-01).
/// <para>
/// Enregistré après <c>DatabaseInitializer</c> : les migrations doivent être appliquées
/// avant qu'un compte puisse être écrit. L'ordre d'enregistrement des services hébergés
/// détermine l'ordre de démarrage, et c'est la seule garantie disponible ici.
/// </para>
/// </summary>
public sealed class AdminSeedStartupTask(
    IServiceScopeFactory scopeFactory,
    ILogger<AdminSeedStartupTask> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        using var portee = scopeFactory.CreateScope();
        var amorceur = portee.ServiceProvider.GetRequiredService<AdminSeeder>();

        // Une exception ici empêche volontairement le démarrage : mieux vaut une API
        // qui refuse de servir qu'une instance sans administrateur, ou pire, avec un
        // identifiant par défaut (RG-ADM-11).
        var cree = await amorceur.SeedAsync(cancellationToken).ConfigureAwait(false);

        if (cree)
        {
            logger.LogWarning(
                "Premier démarrage : administrateur de plateforme amorcé. "
                + "Se connecter, changer le mot de passe, puis retirer ADMIN_PASSWORD.");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
