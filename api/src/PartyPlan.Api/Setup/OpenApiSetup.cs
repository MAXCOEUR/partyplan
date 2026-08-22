namespace PartyPlan.Api.Setup;

using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.OpenApi;

/// <summary>
/// Contrat OpenAPI. Il est la source de la génération du client Dart (§8.1) : il doit
/// donc rester exact, et non décoratif.
/// </summary>
public static class OpenApiSetup
{
    private const string BearerScheme = "Bearer";

    public const string DocumentName = "v1";

    public static IServiceCollection AddPartyPlanOpenApi(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddOpenApi(DocumentName, options =>
        {
            options.AddDocumentTransformer((document, _, _) =>
            {
                document.Info = new OpenApiInfo
                {
                    Title = "PartyPlan API",
                    Version = "v1",
                    Description = "API de PartyPlan. Événements privés par défaut (RG-EVT-01).",
                };
                document.Components ??= new OpenApiComponents();
                document.Components.SecuritySchemes ??=
                    new Dictionary<string, IOpenApiSecurityScheme>();
                document.Components.SecuritySchemes[BearerScheme] = new OpenApiSecurityScheme
                {
                    Type = SecuritySchemeType.Http,
                    Scheme = "bearer",
                    BearerFormat = "JWT",
                };

                return Task.CompletedTask;
            });

            options.AddOperationTransformer((operation, context, _) =>
            {
                var metadata = context.Description.ActionDescriptor.EndpointMetadata;
                if (metadata.OfType<IAllowAnonymous>().Any()
                    || !metadata.OfType<IAuthorizeData>().Any())
                {
                    return Task.CompletedTask;
                }

                operation.Security ??= [];
                operation.Security.Add(new OpenApiSecurityRequirement
                {
                    [new OpenApiSecuritySchemeReference(BearerScheme, context.Document, null)] = [],
                });

                return Task.CompletedTask;
            });
        });

        return services;
    }
}
