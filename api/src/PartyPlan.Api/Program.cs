using System.Diagnostics.CodeAnalysis;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.HttpOverrides;
using PartyPlan.Api.Setup;
using PartyPlan.Infrastructure;
using PartyPlan.Infrastructure.Http;
using PartyPlan.Infrastructure.Idempotency;
using PartyPlan.Modules.Users.Application;
using PartyPlan.SharedKernel.Modules;

var builder = WebApplication.CreateBuilder(args);

// --- Journalisation structurée (NF-OPS-02) ---------------------------------------
// Sortie JSON en toutes circonstances : les journaux sont destinés à être agrégés,
// pas relus à l'œil dans un terminal.
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.UseUtcTimestamp = true;
});

// --- Refus de démarrage sur configuration dangereuse (RG-DEV-01, RG-ADM-11) ------
ProductionGuard.Validate(builder.Environment, builder.Configuration);

// Hors production, l'identifiant d'amorçage reste valable à chaque démarrage : c'est ce
// qu'attend quiconque suit le README, et le compte devenait sinon inutilisable dès son
// premier changement de mot de passe. La valeur est décidée ici et non lue dans la
// configuration : aucun fichier d'environnement ne peut l'activer en production.
builder.Services.PostConfigure<AdminSeedSettings>(
    options => options.ReapplyPassword = !builder.Environment.IsProduction());

builder.Services.AddInfrastructure(builder.Configuration);

var modules = ModuleRegistry.Discover([.. ModuleAssemblies.All]);
builder.Services.AddModules(builder.Configuration, modules);

// Les énumérations sortent nommées, jamais numérotées. Sans ce réglage, un rôle
// plateforme partait en « 0 » ou « 2 » là où le reste de l'API et l'application le
// nomment : la liste des comptes n'a jamais pu s'afficher, l'écran annonçant une panne
// réseau alors que le serveur avait répondu. Un nombre est en outre un mauvais contrat —
// insérer une valeur au milieu de l'énumération renumérote silencieusement les autres.
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

builder.Services.AddPartyPlanProblemDetails();
builder.Services.AddPartyPlanRateLimiting(builder.Configuration);
builder.Services.AddPartyPlanAuthentication(builder.Configuration);
builder.Services.AddPartyPlanOpenApi();

// Amorçage du premier administrateur, après les migrations (EF-ADM-01, RG-ADM-09).
builder.Services.AddHostedService<AdminSeedStartupTask>();

// Temps réel (§9). Aucun backplane : RG-RT-04 impose une instance unique tant qu'un ADR
// n'a pas acté le contraire.
builder.Services.AddSignalR();

// Origines autorisées : l'application web et la vitrine, jamais « * ».
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy
        .WithOrigins(allowedOrigins)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials()));

// Derrière le reverse proxy, l'adresse réelle du client vient des en-têtes transmis.
// Sans cela, la limitation de débit partitionnerait sur l'adresse du proxy et
// s'appliquerait à tout le monde à la fois (NF-SEC-04).
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

app.UseForwardedHeaders();
app.UseCorrelationId();
app.UseSecurityHeaders();
app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseRateLimiter();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Le hub vit hors du groupe /v1 : ce n'est pas une ressource REST versionnée, et
// RG-RT-01 fixe son adresse. Monté après l'autorisation, sans quoi son attribut
// [Authorize] n'aurait aucune identité à examiner.
app.MapHub<PartyPlan.Infrastructure.TempsReel.EventHub>(
    PartyPlan.Api.Setup.AuthenticationSetup.CheminDuHub);

// Placé après l'autorisation : la revendication n'existe qu'une fois l'identité
// établie (RG-ADM-10).
app.UseMustChangePassword();

// Idempotence (§8.1). Intergiciel et non filtre d'endpoint : un filtre s'exécute après
// le liage des arguments, donc après consommation du corps, et l'empreinte serait
// calculée sur une chaîne vide. Il ne s'active que sur les endpoints qui déclarent
// l'exigence.
app.UseIdempotency();

// Le périmètre d'événements est établi après l'authentification et avant tout
// endpoint : c'est le point unique d'application du cloisonnement (RG-SEC-01).
app.UseEventScope();

// En développement, l'API sert elle-même les photos de profil : le domaine statique
// n'existe pas sur un poste. En production, c'est Caddy qui les sert depuis le volume
// partagé (cdn.partyplan.maxencecoeur.fr).
if (app.Environment.IsDevelopment())
{
    var racineMedias = app.Configuration["Media:RootPath"] ?? "/tmp/partyplan-media";
    Directory.CreateDirectory(racineMedias);

    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(
            Path.GetFullPath(racineMedias)),
        RequestPath = "/media",
    });
}

var v1 = app.MapGroup("/v1");
v1.MapModules(modules);

// --- Santé (NF-OPS-01) ------------------------------------------------------------
// Vivacité : le processus répond. Disponibilité : la base est joignable. Confondre
// les deux ferait redémarrer l'API à chaque incident de base.
app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = _ => false,
});

app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
});

app.MapOpenApi($"/openapi/{OpenApiSetup.DocumentName}.json");

if (app.Logger.IsEnabled(LogLevel.Information))
{
    app.Logger.LogInformation(
        "PartyPlan API démarrée — environnement {Environment}, modules : {Modules}",
        app.Environment.EnvironmentName,
        string.Join(", ", modules.Select(m => m.Name)));
}

await app.RunAsync().ConfigureAwait(false);

/// <summary>
/// Point d'entrée exposé pour les tests d'intégration, qui construisent l'hôte réel
/// plutôt qu'un substitut : un test qui ne traverse pas l'authentification, les filtres
/// et la base ne prouve pas le cloisonnement.
/// </summary>
[SuppressMessage("Design", "CA1052:Les types de conteneurs statiques doivent être Static ou NotInheritable",
    Justification = "Classe générée par le compilateur pour un programme de niveau supérieur.")]
public partial class Program
{
}
