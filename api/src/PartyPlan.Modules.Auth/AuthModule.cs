namespace PartyPlan.Modules.Auth;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Auth.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Auth » : les mécanismes de sécurité, sans persistance.
/// <para>
/// Il ne possède aucune table. Le compte, les sessions et les jetons appartiennent au
/// module Users : l'authentification et le compte sont le même agrégat, et les séparer
/// aurait imposé un contrat inter-modules pour chaque connexion. Auth fournit ici le
/// hachage, la politique de mot de passe et l'émission des jetons — trois mécanismes
/// purs, réutilisables et testables sans base.
/// </para>
/// </summary>
public sealed class AuthModule : IModule
{
    public string Name => "Auth";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IPasswordPolicy, PasswordPolicy>();

        services.AddOptions<TokenOptions>()
            .Bind(configuration.GetSection(TokenOptions.SectionName))
            .Validate(
                o => !string.IsNullOrWhiteSpace(o.SigningKey) && o.SigningKey.Length >= 32,
                "Jwt:SigningKey est absente ou fait moins de 32 caractères.")
            .ValidateOnStart();

        services.AddSingleton<ITokenService, TokenService>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes)
    {
        // Les endpoints d'authentification vivent dans le module Users, propriétaire du
        // compte : ils écrivent en base, ce que ce module ne fait pas.
    }
}
