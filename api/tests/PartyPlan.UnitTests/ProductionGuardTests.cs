namespace PartyPlan.UnitTests;

using Microsoft.Extensions.Configuration;
using PartyPlan.Api.Setup;
using PartyPlan.Infrastructure.Options;
using Shouldly;
using Xunit;

/// <summary>
/// Garde de production (RG-DEV-01, RG-ADM-11). Ces tests protègent contre le scénario
/// le plus coûteux du projet : une mise en production démarrant avec un identifiant
/// de développement documenté publiquement.
/// </summary>
public sealed class ProductionGuardTests
{
    [Fact]
    public void En_developpement_aucune_verification_n_est_appliquee()
    {
        var configuration = Build([]);

        Should.NotThrow(() => ProductionGuard.Validate(Environment("Development"), configuration));
    }

    [Fact]
    public void En_production_une_cle_de_signature_de_developpement_est_refusee()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = "cle_de_developpement_non_secrete_32c",
            ["Admin:Email"] = "admin@partyplan.fr",
            ["Admin:Password"] = "UnMotDePasseSolide2026",
        });

        var exception = Should.Throw<InvalidOperationException>(
            () => ProductionGuard.Validate(Environment("Production"), configuration));

        exception.Message.ShouldContain("valeur de développement");
    }

    [Fact]
    public void En_production_une_cle_trop_courte_est_refusee()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = "trop_court",
            ["Admin:Email"] = "admin@partyplan.fr",
            ["Admin:Password"] = "UnMotDePasseSolide2026",
        });

        Should.Throw<InvalidOperationException>(
            () => ProductionGuard.Validate(Environment("Production"), configuration))
            .Message.ShouldContain("32 caractères");
    }

    [Fact]
    public void En_production_l_adresse_de_l_administrateur_est_obligatoire()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = new string('k', 48),
        });

        Should.Throw<InvalidOperationException>(
            () => ProductionGuard.Validate(Environment("Production"), configuration))
            .Message.ShouldContain("Admin:Email");
    }

    [Fact]
    public void En_production_un_mot_de_passe_administrateur_trop_court_est_refuse()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = new string('k', 48),
            ["Admin:Email"] = "admin@partyplan.fr",
            ["Admin:Password"] = "court",
        });

        Should.Throw<InvalidOperationException>(
            () => ProductionGuard.Validate(Environment("Production"), configuration))
            .Message.ShouldContain($"{AdminSeedOptions.MinPasswordLength} caractères");
    }

    [Fact]
    public void En_production_le_jeu_de_donnees_de_demonstration_est_refuse()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = new string('k', 48),
            ["Admin:Email"] = "admin@partyplan.fr",
            ["Admin:Password"] = "UnMotDePasseSolide2026",
            ["Database:SeedDemoData"] = "true",
        });

        Should.Throw<InvalidOperationException>(
            () => ProductionGuard.Validate(Environment("Production"), configuration))
            .Message.ShouldContain("SeedDemoData");
    }

    [Fact]
    public void Une_configuration_de_production_correcte_passe()
    {
        var configuration = Build(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = new string('k', 48),
            ["Admin:Email"] = "admin@partyplan.fr",
            ["Admin:Password"] = "UnMotDePasseSolide2026",
        });

        Should.NotThrow(() => ProductionGuard.Validate(Environment("Production"), configuration));
    }

    [Fact]
    public void L_amorcage_incomplet_est_refuse()
    {
        Should.Throw<InvalidOperationException>(() => ProductionGuard.ValidateAdminSeed(
            Environment("Production"),
            new AdminSeedOptions { Email = "admin@partyplan.fr", Password = null }));
    }

    [Fact]
    public void L_amorcage_complet_est_accepte()
    {
        Should.NotThrow(() => ProductionGuard.ValidateAdminSeed(
            Environment("Production"),
            new AdminSeedOptions { Email = "admin@partyplan.fr", Password = "UnMotDePasseSolide2026" }));
    }

    private static IConfiguration Build(Dictionary<string, string?> values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    private static Microsoft.Extensions.Hosting.Internal.HostingEnvironment Environment(string name) =>
        new() { EnvironmentName = name };
}

/// <summary>
/// Critère 3 du §18 : refus de démarrage lorsque l'amorçage de l'administrateur est
/// incomplet.
/// <para>
/// Vérifié séparément de <see cref="ProductionGuardTests"/> : la garde de configuration
/// s'exécute au démarrage, tandis que celle-ci ne s'applique qu'au moment de l'amorçage,
/// c'est-à-dire lorsque aucun administrateur n'existe encore en base.
/// </para>
/// </summary>
public sealed class AdminSeedGuardTests
{
    [Theory]
    [InlineData(null, "UnMotDePasseSolide2026")]
    [InlineData("", "UnMotDePasseSolide2026")]
    [InlineData("admin@partyplan.fr", null)]
    [InlineData("admin@partyplan.fr", "")]
    [InlineData("admin@partyplan.fr", "court")]
    [InlineData("admin@partyplan.fr", "onzecarac.")]
    public void Un_amorcage_incomplet_refuse_le_demarrage(string? adresse, string? motDePasse)
    {
        // Sans ce refus, l'instance démarrerait sans administrateur — ou, pire, avec un
        // identifiant par défaut connu (RG-ADM-11).
        Should.Throw<InvalidOperationException>(() => ProductionGuard.ValidateAdminSeed(
                Env("Production"),
                new AdminSeedOptions { Email = adresse, Password = motDePasse }))
            .Message.ShouldContain("RG-ADM-11");
    }

    [Fact]
    public void Un_mot_de_passe_de_douze_caracteres_exactement_est_accepte()
    {
        // Frontière de la règle RG-AUTH-01 : douze caractères suffisent.
        Should.NotThrow(() => ProductionGuard.ValidateAdminSeed(
            Env("Production"),
            new AdminSeedOptions
            {
                Email = "admin@partyplan.fr",
                Password = new string('a', AdminSeedOptions.MinPasswordLength),
            }));
    }

    [Fact]
    public void La_garde_s_applique_aussi_en_developpement()
    {
        // Un développeur qui vide ADMIN_PASSWORD doit être averti tout de suite, et non
        // découvrir l'absence d'administrateur en cherchant à se connecter.
        Should.Throw<InvalidOperationException>(() => ProductionGuard.ValidateAdminSeed(
            Env("Development"),
            new AdminSeedOptions { Email = "admin@partyplan.local", Password = null }));
    }

    private static Microsoft.Extensions.Hosting.Internal.HostingEnvironment Env(string nom) =>
        new() { EnvironmentName = nom };
}
