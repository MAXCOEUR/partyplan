namespace PartyPlan.Api.Setup;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using PartyPlan.Infrastructure.Options;

/// <summary>
/// Refuse le démarrage lorsqu'une valeur de commodité destinée au développement se
/// retrouve en production (RG-DEV-01, RG-ADM-11).
/// <para>
/// Volontairement bruyant : une application qui démarre avec un identifiant par défaut
/// connu est la faille la plus évidente qu'un produit puisse présenter.
/// </para>
/// </summary>
public static class ProductionGuard
{
    /// <summary>Valeurs de développement documentées dans .env.example, à bannir en production.</summary>
    private static readonly string[] ForbiddenSecrets =
    [
        "cle_de_developpement_non_secrete_32c",
        "MotDePasseDeDeveloppement",
        "change_me",
        "changeme",
    ];

    public static void Validate(IHostEnvironment environment, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(environment);
        ArgumentNullException.ThrowIfNull(configuration);

        if (!environment.IsProduction())
        {
            return;
        }

        var problems = new List<string>();

        var signingKey = configuration["Jwt:SigningKey"];
        if (string.IsNullOrWhiteSpace(signingKey) || signingKey.Length < 32)
        {
            problems.Add("Jwt:SigningKey est absente ou fait moins de 32 caractères.");
        }
        else if (ForbiddenSecrets.Contains(signingKey, StringComparer.Ordinal))
        {
            problems.Add("Jwt:SigningKey porte une valeur de développement (RG-DEV-01).");
        }

        var adminEmail = configuration[$"{AdminSeedOptions.SectionName}:Email"];
        if (string.IsNullOrWhiteSpace(adminEmail))
        {
            problems.Add($"{AdminSeedOptions.SectionName}:Email est absente (RG-ADM-11).");
        }

        var adminPassword = configuration[$"{AdminSeedOptions.SectionName}:Password"];
        if (!string.IsNullOrWhiteSpace(adminPassword))
        {
            if (adminPassword.Length < AdminSeedOptions.MinPasswordLength)
            {
                problems.Add(
                    $"{AdminSeedOptions.SectionName}:Password fait moins de "
                    + $"{AdminSeedOptions.MinPasswordLength} caractères (RG-AUTH-01).");
            }
            else if (ForbiddenSecrets.Contains(adminPassword, StringComparer.Ordinal))
            {
                problems.Add(
                    $"{AdminSeedOptions.SectionName}:Password porte une valeur de développement "
                    + "(RG-DEV-01).");
            }
        }

        if (configuration.GetValue<bool>($"{DatabaseOptions.SectionName}:SeedDemoData"))
        {
            problems.Add("Database:SeedDemoData est activé, ce qui est réservé au développement (NF-DEV-07).");
        }

        if (problems.Count > 0)
        {
            throw new InvalidOperationException(
                "Démarrage refusé en production :"
                + Environment.NewLine
                + string.Join(Environment.NewLine, problems.Select(p => $"  - {p}"))
                + Environment.NewLine
                + "Voir infra/compose/.env.example et docs/cahier-des-charges.md §13.4.");
        }
    }

    /// <summary>
    /// Vérifie que l'amorçage de l'administrateur est possible. Appelé lorsque aucun
    /// <c>PlatformAdmin</c> n'existe encore en base (RG-ADM-11).
    /// </summary>
    public static void ValidateAdminSeed(IHostEnvironment environment, AdminSeedOptions options)
    {
        ArgumentNullException.ThrowIfNull(environment);
        ArgumentNullException.ThrowIfNull(options);

        if (!string.IsNullOrWhiteSpace(options.Email)
            && !string.IsNullOrWhiteSpace(options.Password)
            && options.Password.Length >= AdminSeedOptions.MinPasswordLength)
        {
            return;
        }

        throw new InvalidOperationException(
            "Aucun administrateur de plateforme n'existe et l'amorçage est incomplet. "
            + $"Renseigner {AdminSeedOptions.SectionName}:Email et un "
            + $"{AdminSeedOptions.SectionName}:Password de "
            + $"{AdminSeedOptions.MinPasswordLength} caractères minimum (RG-ADM-11).");
    }
}
