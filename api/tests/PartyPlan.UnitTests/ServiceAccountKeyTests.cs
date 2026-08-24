namespace PartyPlan.UnitTests;

using System.Security.Cryptography;
using PartyPlan.Infrastructure.Notifications;
using Shouldly;
using Xunit;

/// <summary>
/// Lecture de la clé de compte de service.
/// <para>
/// Aucun de ces cas ne doit faire échouer le démarrage : sans clé lisible, l'application
/// journalise ses notifications et continue (règle 5, NF-DEV-04). Une instance à l'arrêt
/// coûte plus cher qu'une notification perdue.
/// </para>
/// </summary>
public sealed class ServiceAccountKeyTests
{
    [Fact]
    public void Un_chemin_absent_ne_pose_aucun_probleme()
    {
        // Le cas normal du développement : il n'y a pas de clé, et ce n'est pas une erreur.
        var cle = ServiceAccountKey.Lire(null, out var probleme);

        cle.ShouldBeNull();
        probleme.ShouldBeNull();
    }

    [Fact]
    public void Un_fichier_inexistant_est_signale()
    {
        var cle = ServiceAccountKey.Lire("/tmp/absent-de-toute-machine.json", out var probleme);

        cle.ShouldBeNull();
        // Signalé, car le chemin a été fourni : c'est une intention non satisfaite.
        probleme.ShouldNotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Un_json_illisible_est_signale_sans_lever()
    {
        var chemin = Path.GetTempFileName();
        File.WriteAllText(chemin, "{ ceci n'est pas du json");

        try
        {
            var cle = ServiceAccountKey.Lire(chemin, out var probleme);

            cle.ShouldBeNull();
            probleme.ShouldNotBeNullOrWhiteSpace();
        }
        finally
        {
            File.Delete(chemin);
        }
    }

    [Fact]
    public void Un_champ_manquant_est_signale_en_le_nommant()
    {
        var chemin = Path.GetTempFileName();
        File.WriteAllText(chemin, """{"type":"service_account","project_id":"p"}""");

        try
        {
            var cle = ServiceAccountKey.Lire(chemin, out var probleme);

            cle.ShouldBeNull();
            // Nommer le champ absent : « clé invalide » enverrait chercher au hasard.
            probleme.ShouldNotBeNull();
            probleme.ShouldContain("client_email");
        }
        finally
        {
            File.Delete(chemin);
        }
    }

    [Fact]
    public void Une_cle_complete_est_lue()
    {
        var chemin = EcrireCleValide();

        try
        {
            var cle = ServiceAccountKey.Lire(chemin, out var probleme);

            probleme.ShouldBeNull();
            cle.ShouldNotBeNull();
            cle.ProjectId.ShouldBe("partyplan-test");
            cle.ClientEmail.ShouldBe("robot@partyplan-test.iam.gserviceaccount.com");
            cle.PrivateKeyPem.ShouldContain("BEGIN PRIVATE KEY");
        }
        finally
        {
            File.Delete(chemin);
        }
    }

    [Fact]
    public void Une_cle_privee_qui_n_est_pas_du_pem_est_signalee()
    {
        var chemin = Path.GetTempFileName();
        File.WriteAllText(
            chemin,
            """
            {"type":"service_account","project_id":"p",
             "client_email":"r@p.iam.gserviceaccount.com",
             "private_key":"ceci n'est pas une clé"}
            """);

        try
        {
            // Détecté à la lecture et non au premier envoi : découvrir une clé invalide
            // au moment d'envoyer, c'est le découvrir en production.
            var cle = ServiceAccountKey.Lire(chemin, out var probleme);

            cle.ShouldBeNull();
            probleme.ShouldNotBeNullOrWhiteSpace();
        }
        finally
        {
            File.Delete(chemin);
        }
    }

    [Fact]
    public void Une_cle_illisible_avertit_sans_lever()
    {
        var chemin = Path.GetTempFileName();
        File.WriteAllText(chemin, "pas du json");
        var journal = new JournalDeTest();

        try
        {
            var cle = PushSenderFactory.CleUtilisable(chemin, journal);

            cle.ShouldBeNull();
            // Avertissement et non erreur : l'application démarre, en le disant.
            journal.Avertissements.ShouldNotBeEmpty();
        }
        finally
        {
            File.Delete(chemin);
        }
    }

    [Fact]
    public void Aucune_cle_configuree_n_avertit_pas()
    {
        var journal = new JournalDeTest();

        // Le cas normal du développement : informer, jamais avertir. Un avertissement à
        // chaque démarrage local finit par être ignoré, y compris quand il compte.
        PushSenderFactory.CleUtilisable(null, journal).ShouldBeNull();

        journal.Avertissements.ShouldBeEmpty();
    }

    // ------------------------------------------------------------------ aides ----

    /// <summary>Écrit une clé de service valide, avec une paire RSA engendrée sur place.</summary>
    internal static string EcrireCleValide(string projectId = "partyplan-test")
    {
        using var rsa = RSA.Create(2048);
        var pem = rsa.ExportPkcs8PrivateKeyPem().ReplaceLineEndings("\n");

        var chemin = Path.GetTempFileName();
        File.WriteAllText(
            chemin,
            System.Text.Json.JsonSerializer.Serialize(new
            {
                type = "service_account",
                project_id = projectId,
                client_email = "robot@partyplan-test.iam.gserviceaccount.com",
                private_key = pem,
                token_uri = "https://oauth2.googleapis.com/token",
            }));

        return chemin;
    }
}

/// <summary>Journal qui retient les avertissements, pour les affirmer.</summary>
internal sealed class JournalDeTest : Microsoft.Extensions.Logging.ILogger
{
    internal List<string> Avertissements { get; } = [];

    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

    public bool IsEnabled(Microsoft.Extensions.Logging.LogLevel logLevel) => true;

    public void Log<TState>(
        Microsoft.Extensions.Logging.LogLevel logLevel,
        Microsoft.Extensions.Logging.EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (logLevel >= Microsoft.Extensions.Logging.LogLevel.Warning)
        {
            Avertissements.Add(formatter(state, exception));
        }
    }
}
