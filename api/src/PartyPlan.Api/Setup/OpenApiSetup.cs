namespace PartyPlan.Api.Setup;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.OpenApi;

/// <summary>
/// Contrat OpenAPI. Il est la source de la génération du client Dart (§8.1) : il doit
/// donc rester exact, et non décoratif.
/// </summary>
public static class OpenApiSetup
{
    public const string DocumentName = "v1";

    public static IServiceCollection AddPartyPlanOpenApi(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddOpenApi(DocumentName, options =>
            options.AddDocumentTransformer((document, _, _) =>
            {
                document.Info = new OpenApiInfo
                {
                    Title = "PartyPlan API",
                    Version = "v1",
                    Description = "API de PartyPlan. Événements privés par défaut (RG-EVT-01).",
                };

                return Task.CompletedTask;
            }));

        return services;
    }
}
