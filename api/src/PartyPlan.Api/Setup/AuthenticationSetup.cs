namespace PartyPlan.Api.Setup;

using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using PartyPlan.Infrastructure.Identity;
using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Authentification par jeton porteur. Les endpoints d'émission arrivent en V0.5
/// (lot 0.8) ; la validation est en place dès maintenant afin que
/// <c>RequireAuthorization</c> ait un sens réel plutôt que décoratif.
/// </summary>
public static class AuthenticationSetup
{
    /// <summary>Réservée aux rôles plateforme disposant de tous les droits (RG-ADM-05).</summary>
    public const string PlatformAdminPolicy = "PlatformAdmin";

    /// <summary>Consultation et dépannage : Support ou PlatformAdmin (RG-ADM-05).</summary>
    public const string PlatformStaffPolicy = "PlatformStaff";

    public static IServiceCollection AddPartyPlanAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        var signingKey = configuration["Jwt:SigningKey"]
            ?? throw new InvalidOperationException(
                "Jwt:SigningKey est absente. Voir .env.example (RG-DEV-02).");

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = configuration["Jwt:Issuer"],
                    ValidateAudience = true,
                    ValidAudience = configuration["Jwt:Audience"],
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey)),
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                };
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = context =>
                    {
                        if (!Guid.TryParse(
                                context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier),
                                out _))
                        {
                            context.Fail("Le jeton ne désigne pas un compte utilisateur.");
                        }

                        return Task.CompletedTask;
                    },
                };
            });

        services.AddAuthorization(options =>
        {
            options.DefaultPolicy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .RequireClaim(ClaimTypes.NameIdentifier)
                .Build();

            // Le rôle seul ouvre le back-office : RG-ADM-04 est abrogée par l'ADR 0007,
            // qui porte la décision et ce qu'elle coûte — un mot de passe devient
            // l'unique protection d'un compte capable de réinitialiser et de supprimer
            // tous les autres. L'exigence rendait l'administration inatteignable à son
            // seul administrateur.
            //
            // Le rôle est porté par le jeton, la garde s'évalue donc sans requête en
            // base. Un compte promu conserve un ancien jeton jusqu'à son renouvellement.
            options.AddPolicy(PlatformAdminPolicy, policy => policy
                .RequireAuthenticatedUser()
                .RequireClaim(PartyPlanClaims.PlatformRole, nameof(PlatformRole.PlatformAdmin)));

            options.AddPolicy(PlatformStaffPolicy, policy => policy
                .RequireAuthenticatedUser()
                .RequireClaim(
                    PartyPlanClaims.PlatformRole,
                    nameof(PlatformRole.Support),
                    nameof(PlatformRole.PlatformAdmin)));
        });

        return services;
    }
}
