# Transport des notifications poussées — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans` pour dérouler ce plan tâche par tâche. Les
> étapes sont des cases à cocher (`- [ ]`).

**But :** qu'une notification partie du serveur arrive sur un téléphone Android, puis sur un
navigateur. Aucun déclencheur métier n'est branché.

**Architecture :** `FirebasePushSender` remplace `ConsolePushSender` quand une clé de compte
de service est lisible, derrière le contrat `IPushSender` inchangé. L'appel à FCM HTTP v1
passe par un jeton OAuth2 obtenu en signant un JWT avec `Microsoft.IdentityModel`, sans
aucune dépendance nouvelle. Le module `Notifications` mappe ses propres endpoints
d'enregistrement d'appareil et expose un contrat public pour mettre un jeton au rebut.

**Pile :** ASP.NET Core 10, EF Core 10, Flutter 3.38, `firebase_core` + `firebase_messaging`,
FCM HTTP v1.

**Spec :** `docs/superpowers/specs/2026-08-24-notifications-transport-firebase-design.md`

## Précision apportée à la spec pendant la planification

La spec dit que `FirebasePushSender` marque `push_devices.disabled_at` sur un jeton refusé,
et que le module `Notifications` possède cette table. Les deux ensemble exigent un contrat :
l'émetteur vit dans l'Infrastructure et ne doit pas écrire dans la table d'un module.

**Ajout : `IPushDeviceRegistry`**, contrat public du module `Notifications`, sur le modèle de
`IExpenseFromPurchase`, `IEventMembership`, `ISettlementStatus` et `IUserIdentityLookup`.
`IPushSender` reste inchangé, comme la spec l'exige.

Conséquence : `FirebasePushSender` devient **scoped** (il consomme un service scoped), et le
cache du jeton OAuth2 est isolé dans `GoogleAccessTokens`, **singleton**. Sans cette
séparation, le jeton serait redemandé à chaque envoi.

## Contraintes globales

Reprises du cahier des charges et de `CLAUDE.md`, valeurs exactes.

- **Aucune dépendance NuGet nouvelle.** `Directory.Packages.props` ne gagne aucune entrée.
- **Règle 5 / `NF-DEV-04`** : sans clé, l'application entière fonctionne et les notifications
  se lisent dans la console. Une clé illisible n'empêche jamais le démarrage.
- **`SendAsync` ne lève jamais.** Perdre l'avis vaut mieux que perdre l'action qui l'a
  déclenché.
- **Règle 6** : un module n'accède pas aux tables d'un autre. Interface publique uniquement,
  vérifiée par `make frontieres`.
- **`NF-SEC-02`** : aucun secret dans le dépôt. `NF-SEC-03` : le jeton d'appareil est tronqué
  en journal.
- **`NF-DEV-10`** : les tests tournent sans réseau. Aucun test n'appelle FCM ; la frontière
  est le `HttpClient`, substitué.
- **Langue** : français dans l'interface et les commentaires, anglais dans le code et les
  identifiants de base. Dates en JJ/MM/AAAA.
- **Commits conventionnels avec périmètre** : `feat(notifications):`, `fix(notifications):`.
- **`make verif` passe avant chaque commit.**

## Séquencement — Android d'abord

La clé VAPID du push web n'est pas engendrée : le CLI Firebase ne l'expose pas, elle demande
un passage en console. **Les tâches 1 à 7 et 9 ne l'exigent pas.** À la fin de la tâche 7,
Android reçoit des notifications. La tâche 8, seule bloquée, ajoute le Web.

Ne pas commencer la tâche 8 sans la clé VAPID en main.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `Infrastructure/Notifications/ServiceAccountKey.cs` | Lire et valider la clé de compte de service. Ne parle à personne. |
| `Infrastructure/Notifications/GoogleAccessTokens.cs` | Obtenir et cacher un jeton OAuth2. Singleton. |
| `Infrastructure/Notifications/FirebasePushSender.cs` | Construire et envoyer le message FCM. Scoped. |
| `Infrastructure/Notifications/PushSenderFactory.cs` | Choisir l'émetteur au démarrage. |
| `SharedKernel/Contracts/IPushDeviceRegistry.cs` | Mise au rebut d'un jeton. Contrat du module Notifications. |
| `Modules.Notifications/Application/DeviceService.cs` | Enregistrer, retirer, mettre au rebut un appareil. |
| `Modules.Notifications/Endpoints/DeviceEndpoints.cs` | `/v1/me/devices`. |
| `app/lib/core/network/appareils_api.dart` | Client des deux endpoints. |
| `app/lib/core/notifications/service_notifications.dart` | Permission, jeton, enregistrement. |
| `app/lib/core/notifications/lien_notification.dart` | Ouverture du lien profond. |
| `app/lib/features/evenement/sections/section_notifications.dart` | Demande du consentement. |

---

### Tâche 1 : lire la clé de compte de service et choisir l'émetteur

**Fichiers :**
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/ServiceAccountKey.cs`
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/PushSenderFactory.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/Notifications/ConsolePushSender.cs` (PushOptions)
- Modifier : `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`
- Test : `api/tests/PartyPlan.UnitTests/ServiceAccountKeyTests.cs`

**Interfaces :**
- Produit : `ServiceAccountKey(string ProjectId, string ClientEmail, string PrivateKeyPem)`,
  `ServiceAccountKey.Lire(string? chemin, out string? probleme) → ServiceAccountKey?`,
  `PushOptions.FirebaseServiceAccountPath`

- [ ] **Étape 1 : écrire le test qui échoue**

`api/tests/PartyPlan.UnitTests/ServiceAccountKeyTests.cs`

```csharp
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
```

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~ServiceAccountKey"`
Attendu : ÉCHEC de compilation, `ServiceAccountKey` introuvable.

- [ ] **Étape 3 : écrire `ServiceAccountKey`**

`api/src/PartyPlan.Infrastructure/Notifications/ServiceAccountKey.cs`

```csharp
namespace PartyPlan.Infrastructure.Notifications;

using System.Security.Cryptography;
using System.Text.Json;

/// <summary>
/// Clé de compte de service Google, telle que Firebase la remet.
/// <para>
/// Lue au démarrage et validée immédiatement, clé privée comprise : découvrir un PEM
/// invalide au premier envoi, c'est le découvrir en production, un soir de soirée.
/// </para>
/// </summary>
public sealed record ServiceAccountKey(
    string ProjectId,
    string ClientEmail,
    string PrivateKeyPem)
{
    /// <summary>
    /// Lit la clé au chemin indiqué.
    /// <para>
    /// Renvoie <c>null</c> dans tous les cas d'échec, et ne lève jamais : l'absence de clé
    /// est le cas normal du développement (règle 5), et une clé cassée ne doit pas
    /// empêcher l'application de démarrer. <paramref name="probleme"/> reste <c>null</c>
    /// lorsqu'aucun chemin n'était demandé, et porte sinon de quoi corriger.
    /// </para>
    /// </summary>
    public static ServiceAccountKey? Lire(string? chemin, out string? probleme)
    {
        probleme = null;

        if (string.IsNullOrWhiteSpace(chemin))
        {
            return null;
        }

        if (!File.Exists(chemin))
        {
            probleme = $"Aucun fichier au chemin « {chemin} ».";
            return null;
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(File.ReadAllText(chemin));
        }
        catch (Exception erreur) when (erreur is JsonException or IOException
                                          or UnauthorizedAccessException)
        {
            probleme = $"Le fichier « {chemin} » n'est pas un JSON lisible : {erreur.Message}";
            return null;
        }

        using (document)
        {
            var racine = document.RootElement;

            var projet = Texte(racine, "project_id");
            var courriel = Texte(racine, "client_email");
            var privee = Texte(racine, "private_key");

            var manquants = new List<string>();
            if (projet is null) { manquants.Add("project_id"); }
            if (courriel is null) { manquants.Add("client_email"); }
            if (privee is null) { manquants.Add("private_key"); }

            if (manquants.Count > 0)
            {
                probleme = $"Champs absents du fichier « {chemin} » : {string.Join(", ", manquants)}.";
                return null;
            }

            // La clé privée est éprouvée maintenant, pas au premier envoi.
            try
            {
                using var rsa = RSA.Create();
                rsa.ImportFromPem(privee);
            }
            catch (ArgumentException erreur)
            {
                probleme = $"La clé privée de « {chemin} » n'est pas un PEM valide : {erreur.Message}";
                return null;
            }

            return new ServiceAccountKey(projet!, courriel!, privee!);
        }
    }

    private static string? Texte(JsonElement racine, string nom) =>
        racine.TryGetProperty(nom, out var valeur) && valeur.ValueKind == JsonValueKind.String
            ? valeur.GetString()
            : null;
}
```

- [ ] **Étape 4 : lancer le test, vérifier qu'il passe**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~ServiceAccountKey"`
Attendu : 6 tests réussis.

- [ ] **Étape 5 : renommer l'option**

Dans `api/src/PartyPlan.Infrastructure/Notifications/ConsolePushSender.cs`, remplacer la
propriété de `PushOptions` :

```csharp
public sealed class PushOptions
{
    public const string SectionName = "Push";

    /// <summary>
    /// Chemin du fichier de clé de compte de service Firebase. Vide en développement :
    /// les notifications sont alors journalisées (NF-DEV-04).
    /// <para>
    /// Un chemin et non le contenu JSON : le déploiement se fait sur un NAS sans fichier
    /// « .env », en remplaçant les valeurs dans le compose. Y coller 2 300 caractères
    /// contenant une clé privée PEM est fonctionnel mais piégeux — une virgule mal
    /// échappée et le conteneur ne démarre plus, sans que rien ne l'explique.
    /// </para>
    /// </summary>
    public string? FirebaseServiceAccountPath { get; set; }
}
```

Dans le même fichier, `ConsolePushSender.IsConfigured` devient `false` en dur, avec ce
commentaire — l'avertissement « clé présente mais pas d'émetteur » n'a plus d'objet
puisqu'une clé présente donne maintenant le vrai émetteur :

```csharp
    /// <summary>
    /// Toujours faux : cet émetteur n'envoie rien, par construction. Une clé configurée
    /// donne <c>FirebasePushSender</c>, choisi au démarrage.
    /// </summary>
    public bool IsConfigured => false;
```

Retirer alors le bloc `if (IsConfigured) { ... }` de `SendAsync`, devenu inatteignable.

- [ ] **Étape 6 : écrire la fabrique**

`api/src/PartyPlan.Infrastructure/Notifications/PushSenderFactory.cs`

```csharp
namespace PartyPlan.Infrastructure.Notifications;

using Microsoft.Extensions.Logging;

/// <summary>
/// Choix de l'émetteur de notifications, une seule fois au démarrage.
/// <para>
/// Extrait de l'enregistrement des services afin d'être testable : la décision « avec ou
/// sans Firebase » est celle qui tient la règle 5, et elle mérite un test plutôt qu'une
/// relecture.
/// </para>
/// </summary>
public static class PushSenderFactory
{
    /// <summary>
    /// Renvoie la clé à utiliser, ou <c>null</c> pour rester sur la console.
    /// <para>
    /// Un problème est journalisé en avertissement, jamais levé : une clé cassée ne doit
    /// pas empêcher l'application de démarrer, elle doit la faire retomber sur la console
    /// en le disant.
    /// </para>
    /// </summary>
    public static ServiceAccountKey? CleUtilisable(string? chemin, ILogger logger)
    {
        ArgumentNullException.ThrowIfNull(logger);

        var cle = ServiceAccountKey.Lire(chemin, out var probleme);

        if (probleme is not null)
        {
            logger.LogWarning(
                "Clé Firebase inutilisable, les notifications seront journalisées : {Probleme}",
                probleme);
        }
        else if (cle is null)
        {
            logger.LogInformation(
                "Aucune clé Firebase configurée : les notifications sont journalisées (NF-DEV-04).");
        }

        return cle;
    }
}
```

- [ ] **Étape 7 : tester la décision elle-même**

La spec exige qu'une clé illisible bascule sur la console **et** avertisse, sans jamais
faire échouer le démarrage. C'est la décision qui tient la règle 5 : elle mérite un test.

Ajouter à `api/tests/PartyPlan.UnitTests/ServiceAccountKeyTests.cs` :

```csharp
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
```

et la doublure de journal, dans le même fichier :

```csharp
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
```

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~ServiceAccountKey"`
Attendu : 8 tests réussis.

- [ ] **Étape 8 : `make verif` puis commit**

```bash
make verif
git add api/src/PartyPlan.Infrastructure/Notifications api/tests/PartyPlan.UnitTests/ServiceAccountKeyTests.cs
git commit -m "feat(notifications): lire la clé de compte de service Firebase"
```

---

### Tâche 2 : jeton OAuth2 Google, signé et caché

**Fichiers :**
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/GoogleAccessTokens.cs`
- Test : `api/tests/PartyPlan.UnitTests/GoogleAccessTokensTests.cs`
- Créer : `api/tests/PartyPlan.UnitTests/Infrastructure/HttpStub.cs`

**Interfaces :**
- Consomme : `ServiceAccountKey` (tâche 1)
- Produit : `GoogleAccessTokens(HttpClient, IClock, ILogger<GoogleAccessTokens>)`,
  `Task<string?> ObtenirAsync(ServiceAccountKey cle, CancellationToken ct)`

- [ ] **Étape 1 : écrire la doublure HTTP**

`api/tests/PartyPlan.UnitTests/Infrastructure/HttpStub.cs`

```csharp
namespace PartyPlan.UnitTests.Infrastructure;

using System.Net;

/// <summary>
/// Gestionnaire HTTP substitué. La frontière des tests est le <c>HttpClient</c> : aucun
/// test ne sort sur le réseau (NF-DEV-10).
/// </summary>
internal sealed class HttpStub(Func<HttpRequestMessage, HttpResponseMessage> repondre)
    : HttpMessageHandler
{
    /// <summary>Requêtes reçues, dans l'ordre. Le corps est déjà lu.</summary>
    internal List<(string Uri, string Corps)> Appels { get; } = [];

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var corps = request.Content is null
            ? string.Empty
            : await request.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        Appels.Add((request.RequestUri!.ToString(), corps));

        return repondre(request);
    }

    internal static HttpResponseMessage Json(HttpStatusCode statut, string corps) =>
        new(statut) { Content = new StringContent(corps, System.Text.Encoding.UTF8, "application/json") };
}
```

- [ ] **Étape 2 : écrire le test qui échoue**

`api/tests/PartyPlan.UnitTests/GoogleAccessTokensTests.cs`

```csharp
namespace PartyPlan.UnitTests;

using System.Net;
using Microsoft.Extensions.Logging.Abstractions;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.UnitTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Obtention du jeton OAuth2 exigé par FCM HTTP v1.
/// <para>
/// Le jeton est caché : le redemander à chaque notification ajouterait un aller-retour
/// réseau par envoi, et la limite de débit de Google finirait par le refuser.
/// </para>
/// </summary>
public sealed class GoogleAccessTokensTests
{
    private static readonly ServiceAccountKey Cle = LireCleDeTest();

    [Fact]
    public async Task Le_jeton_est_demande_a_l_adresse_d_echange_de_google()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            """{"access_token":"jeton-1","expires_in":3600,"token_type":"Bearer"}"""));

        var jetons = Creer(stub, out _);

        var jeton = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        jeton.ShouldBe("jeton-1");
        stub.Appels.Count.ShouldBe(1);
        stub.Appels[0].Uri.ShouldBe("https://oauth2.googleapis.com/token");
        // Le format d'échange est imposé par la RFC 7523.
        stub.Appels[0].Corps.ShouldContain("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer");
        stub.Appels[0].Corps.ShouldContain("assertion=");
    }

    [Fact]
    public async Task Un_second_appel_rapproche_reutilise_le_jeton_cache()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            """{"access_token":"jeton-1","expires_in":3600}"""));

        var jetons = Creer(stub, out var horloge);

        await jetons.ObtenirAsync(Cle, CancellationToken.None);
        horloge.Avancer(TimeSpan.FromMinutes(30));
        var second = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        second.ShouldBe("jeton-1");
        stub.Appels.Count.ShouldBe(1, "le jeton caché devait suffire");
    }

    [Fact]
    public async Task Un_jeton_proche_de_l_expiration_est_renouvele()
    {
        var reponses = 0;
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            $$"""{"access_token":"jeton-{{++reponses}}","expires_in":3600}"""));

        var jetons = Creer(stub, out var horloge);

        await jetons.ObtenirAsync(Cle, CancellationToken.None);
        // La marge de sécurité est d'une minute : à 59 min 10 s, le jeton doit tourner.
        horloge.Avancer(TimeSpan.FromMinutes(59) + TimeSpan.FromSeconds(10));
        var second = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        second.ShouldBe("jeton-2");
        stub.Appels.Count.ShouldBe(2);
    }

    [Fact]
    public async Task Un_refus_de_google_renvoie_null_sans_lever()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.BadRequest,
            """{"error":"invalid_grant"}"""));

        var jetons = Creer(stub, out _);

        // Renvoyer null plutôt que lever : l'appelant journalise et abandonne l'envoi,
        // il ne fait pas échouer l'action métier qui l'a déclenché.
        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBeNull();
    }

    [Fact]
    public async Task Un_refus_n_est_pas_mis_en_cache()
    {
        var reponses = 0;
        var stub = new HttpStub(_ => ++reponses == 1
            ? HttpStub.Json(HttpStatusCode.ServiceUnavailable, "{}")
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"jeton-2","expires_in":3600}"""));

        var jetons = Creer(stub, out _);

        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBeNull();
        // Cacher un échec priverait l'instance de notifications pendant une heure.
        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBe("jeton-2");
    }

    // ------------------------------------------------------------------ aides ----

    private static GoogleAccessTokens Creer(HttpStub stub, out HorlogeDeTest horloge)
    {
        horloge = new HorlogeDeTest();
        return new GoogleAccessTokens(
            new HttpClient(stub),
            horloge,
            NullLogger<GoogleAccessTokens>.Instance);
    }

    private static ServiceAccountKey LireCleDeTest()
    {
        var chemin = ServiceAccountKeyTests.EcrireCleValide();
        try
        {
            return ServiceAccountKey.Lire(chemin, out _)!;
        }
        finally
        {
            File.Delete(chemin);
        }
    }
}
```

Vérifier si `HorlogeDeTest` existe déjà dans `PartyPlan.UnitTests` :
`grep -rn "class HorlogeDeTest\|IClock" api/tests/PartyPlan.UnitTests`. Si oui, la réutiliser
et supprimer le bloc ci-dessous. Sinon, la créer dans
`api/tests/PartyPlan.UnitTests/Infrastructure/HorlogeDeTest.cs` :

```csharp
namespace PartyPlan.UnitTests;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Horloge que le test avance à la main. Le temps réel rendrait le cache intestable.</summary>
internal sealed class HorlogeDeTest : IClock
{
    public DateTimeOffset UtcNow { get; private set; } =
        new(2026, 8, 24, 20, 0, 0, TimeSpan.Zero);

    internal void Avancer(TimeSpan duree) => UtcNow = UtcNow.Add(duree);
}
```

- [ ] **Étape 3 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~GoogleAccessTokens"`
Attendu : ÉCHEC de compilation, `GoogleAccessTokens` introuvable.

- [ ] **Étape 4 : écrire `GoogleAccessTokens`**

`api/src/PartyPlan.Infrastructure/Notifications/GoogleAccessTokens.cs`

```csharp
namespace PartyPlan.Infrastructure.Notifications;

using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Jetons d'accès Google, pour FCM HTTP v1.
/// <para>
/// Écrit à la main plutôt qu'emprunté au paquet <c>FirebaseAdmin</c>, qui tirerait une
/// dizaine d'assemblys Google pour ce seul appel et élargirait la surface analysée par
/// NF-SEC-05. Le dépôt a déjà tranché ainsi deux fois : la RFC 6238, et la validation des
/// jetons Google par <c>GoogleIdentityVerifier</c>.
/// </para>
/// <para>
/// Singleton : le cache du jeton n'a de sens que partagé.
/// </para>
/// </summary>
public sealed class GoogleAccessTokens(
    HttpClient http,
    IClock clock,
    ILogger<GoogleAccessTokens> logger)
{
    /// <summary>Portée minimale : envoyer des messages, rien d'autre.</summary>
    private const string Scope = "https://www.googleapis.com/auth/firebase.messaging";

    private const string TokenUri = "https://oauth2.googleapis.com/token";

    /// <summary>
    /// Marge retirée à la durée de vie annoncée. Un jeton qui expire pendant le vol d'une
    /// requête produirait un échec parfaitement évitable.
    /// </summary>
    private static readonly TimeSpan Marge = TimeSpan.FromSeconds(60);

    private readonly SemaphoreSlim _verrou = new(1, 1);

    private string? _jeton;
    private DateTimeOffset _expiration = DateTimeOffset.MinValue;

    public async Task<string?> ObtenirAsync(
        ServiceAccountKey cle,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(cle);

        if (_jeton is not null && clock.UtcNow + Marge < _expiration)
        {
            return _jeton;
        }

        await _verrou.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            // Revérifié sous verrou : dix envois simultanés ne doivent pas demander dix
            // jetons.
            if (_jeton is not null && clock.UtcNow + Marge < _expiration)
            {
                return _jeton;
            }

            var obtenu = await EchangerAsync(cle, cancellationToken).ConfigureAwait(false);

            if (obtenu is null)
            {
                // Un échec n'est pas mis en cache : le mettre priverait l'instance de
                // notifications pendant toute la durée de vie qu'on lui aurait prêtée.
                return null;
            }

            _jeton = obtenu.AccessToken;
            _expiration = clock.UtcNow.AddSeconds(obtenu.ExpiresIn);

            return _jeton;
        }
        finally
        {
            _verrou.Release();
        }
    }

    private async Task<ReponseJeton?> EchangerAsync(
        ServiceAccountKey cle,
        CancellationToken cancellationToken)
    {
        try
        {
            var corps = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                ["assertion"] = Signer(cle),
            });

            using var reponse = await http
                .PostAsync(new Uri(TokenUri), corps, cancellationToken)
                .ConfigureAwait(false);

            if (!reponse.IsSuccessStatusCode)
            {
                logger.LogError(
                    "Google refuse le jeton d'accès aux notifications : {Statut}.",
                    (int)reponse.StatusCode);

                return null;
            }

            return await reponse.Content
                .ReadFromJsonAsync<ReponseJeton>(cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception erreur) when (erreur is HttpRequestException or TaskCanceledException)
        {
            logger.LogError(erreur, "Jeton d'accès aux notifications inaccessible.");
            return null;
        }
    }

    /// <summary>JWT porteur, tel que l'exige la RFC 7523.</summary>
    private static string Signer(ServiceAccountKey cle)
    {
        // La clé RSA vit le temps de la signature : la conserver ouverte pendant une heure
        // n'apporte rien et garde du matériel cryptographique en mémoire pour rien.
        using var rsa = RSA.Create();
        rsa.ImportFromPem(cle.PrivateKeyPem);

        var maintenant = DateTime.UtcNow;

        var descripteur = new SecurityTokenDescriptor
        {
            Issuer = cle.ClientEmail,
            Audience = TokenUri,
            Claims = new Dictionary<string, object> { ["scope"] = Scope },
            IssuedAt = maintenant,
            NotBefore = maintenant,
            Expires = maintenant.AddMinutes(30),
            SigningCredentials = new SigningCredentials(
                new RsaSecurityKey(rsa.ExportParameters(true)),
                SecurityAlgorithms.RsaSha256),
        };

        return new JsonWebTokenHandler().CreateToken(descripteur);
    }

    private sealed record ReponseJeton(
        [property: JsonPropertyName("access_token")] string AccessToken,
        [property: JsonPropertyName("expires_in")] int ExpiresIn);
}
```

- [ ] **Étape 5 : lancer le test, vérifier qu'il passe**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~GoogleAccessTokens"`
Attendu : 5 tests réussis.

- [ ] **Étape 6 : `make verif` puis commit**

```bash
make verif
git add api/src/PartyPlan.Infrastructure/Notifications/GoogleAccessTokens.cs api/tests/PartyPlan.UnitTests
git commit -m "feat(notifications): obtenir et cacher le jeton d'accès Google"
```

---

### Tâche 3 : envoyer à FCM et mettre au rebut les jetons refusés

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IPushDeviceRegistry.cs`
- Créer : `api/src/PartyPlan.Infrastructure/Notifications/FirebasePushSender.cs`
- Modifier : `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`
- Test : `api/tests/PartyPlan.UnitTests/FirebasePushSenderTests.cs`

**Interfaces :**
- Consomme : `ServiceAccountKey`, `GoogleAccessTokens` (tâches 1 et 2)
- Produit : `IPushDeviceRegistry.DisableAsync(string token, string raison, CancellationToken)`,
  `FirebasePushSender` implémentant `IPushSender`

- [ ] **Étape 1 : écrire le contrat**

`api/src/PartyPlan.SharedKernel/Contracts/IPushDeviceRegistry.cs`

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Mise au rebut d'un appareil. Contrat public du module Notifications, consommé par
/// l'émetteur de notifications de l'Infrastructure.
/// <para>
/// Exposé par contrat et non par accès direct : <c>push_devices</c> appartient au module
/// Notifications, et la règle 6 interdit d'y écrire depuis ailleurs. C'est le même motif
/// que <c>IExpenseFromPurchase</c> ou <c>IEventMembership</c>.
/// </para>
/// </summary>
public interface IPushDeviceRegistry
{
    /// <summary>
    /// Désactive l'appareil portant ce jeton. Idempotent : un jeton déjà désactivé ou
    /// inconnu ne produit rien.
    /// </summary>
    Task DisableAsync(string token, string raison, CancellationToken cancellationToken);
}
```

- [ ] **Étape 2 : écrire le test qui échoue**

`api/tests/PartyPlan.UnitTests/FirebasePushSenderTests.cs`

```csharp
namespace PartyPlan.UnitTests;

using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.UnitTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Envoi d'une notification par FCM HTTP v1.
/// <para>
/// Aucun de ces tests ne sort sur le réseau : la frontière est le <c>HttpClient</c>
/// (NF-DEV-10). Ce qui est vérifié, c'est le corps envoyé et le traitement des réponses,
/// pas la capacité de Google à livrer.
/// </para>
/// </summary>
public sealed class FirebasePushSenderTests
{
    private const string Jeton = "fZ1p:APA91bH_exemple-de-jeton-fcm_qui-est-long";

    [Fact]
    public async Task Le_corps_suit_le_format_http_v1()
    {
        var stub = new HttpStub(_ => HttpStub.Json(HttpStatusCode.OK, """{"name":"projects/p/messages/1"}"""));
        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(
            new PushMessage(Jeton, "Soirée modifiée", "Le lieu a changé", "/events/42"),
            CancellationToken.None);

        stub.Appels.Count.ShouldBe(2, "un échange de jeton, puis l'envoi");
        stub.Appels[1].Uri
            .ShouldBe("https://fcm.googleapis.com/v1/projects/partyplan-test/messages:send");

        var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
        corps.GetProperty("token").GetString().ShouldBe(Jeton);
        corps.GetProperty("notification").GetProperty("title").GetString()
            .ShouldBe("Soirée modifiée");
        corps.GetProperty("notification").GetProperty("body").GetString()
            .ShouldBe("Le lieu a changé");
        // Le lien voyage en données et non en notification : c'est le client qui décide
        // quoi ouvrir, le système n'a pas à connaître nos routes.
        corps.GetProperty("data").GetProperty("deepLink").GetString().ShouldBe("/events/42");
    }

    [Fact]
    public async Task Un_message_sans_lien_ne_porte_pas_de_champ_vide()
    {
        var stub = new HttpStub(_ => HttpStub.Json(HttpStatusCode.OK, """{"name":"n"}"""));
        var emetteur = Creer(stub, new RegistreDeTest());

        await emetteur.SendAsync(
            new PushMessage(Jeton, "Titre", "Corps"),
            CancellationToken.None);

        var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
        corps.TryGetProperty("data", out _).ShouldBeFalse();
    }

    [Fact]
    public async Task Un_jeton_perime_est_mis_au_rebut()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("fcm")
            ? HttpStub.Json(
                HttpStatusCode.NotFound,
                """
                {"error":{"code":404,"status":"NOT_FOUND","details":[
                  {"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError",
                   "errorCode":"UNREGISTERED"}]}}
                """)
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"j","expires_in":3600}"""));

        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        // Un téléphone réinstallé ne doit pas faire échouer les envois indéfiniment.
        registre.Rebuts.ShouldContain(Jeton);
    }

    [Fact]
    public async Task Une_panne_passagere_ne_met_rien_au_rebut()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("fcm")
            ? HttpStub.Json(HttpStatusCode.ServiceUnavailable, """{"error":{"status":"UNAVAILABLE"}}""")
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"j","expires_in":3600}"""));

        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        // FCM indisponible n'est pas un jeton invalide : désactiver l'appareil ici
        // couperait les notifications de tout le monde à la première panne de Google.
        registre.Rebuts.ShouldBeEmpty();
    }

    [Fact]
    public async Task Un_echec_reseau_ne_leve_pas()
    {
        var stub = new HttpStub(_ => throw new HttpRequestException("réseau coupé"));
        var emetteur = Creer(stub, new RegistreDeTest());

        // Le contrat l'exige : perdre l'avis vaut mieux que perdre l'action qui l'a
        // déclenché.
        await Should.NotThrowAsync(() =>
            emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None));
    }

    [Fact]
    public async Task Sans_jeton_d_acces_aucun_envoi_n_est_tente()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("oauth2")
            ? HttpStub.Json(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")
            : HttpStub.Json(HttpStatusCode.OK, "{}"));

        var emetteur = Creer(stub, new RegistreDeTest());

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        stub.Appels.ShouldHaveSingleItem();
        stub.Appels[0].Uri.ShouldContain("oauth2");
    }

    // ------------------------------------------------------------------ aides ----

    private static FirebasePushSender Creer(HttpStub stub, IPushDeviceRegistry registre)
    {
        var chemin = ServiceAccountKeyTests.EcrireCleValide();
        ServiceAccountKey cle;
        try
        {
            cle = ServiceAccountKey.Lire(chemin, out _)!;
        }
        finally
        {
            File.Delete(chemin);
        }

        var client = new HttpClient(stub);

        return new FirebasePushSender(
            cle,
            new GoogleAccessTokens(client, new HorlogeDeTest(), NullLogger<GoogleAccessTokens>.Instance),
            client,
            registre,
            NullLogger<FirebasePushSender>.Instance);
    }

    private sealed class RegistreDeTest : IPushDeviceRegistry
    {
        internal List<string> Rebuts { get; } = [];

        public Task DisableAsync(string token, string raison, CancellationToken cancellationToken)
        {
            Rebuts.Add(token);
            return Task.CompletedTask;
        }
    }
}
```

- [ ] **Étape 3 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~FirebasePushSender"`
Attendu : ÉCHEC de compilation, `FirebasePushSender` introuvable.

- [ ] **Étape 4 : écrire `FirebasePushSender`**

`api/src/PartyPlan.Infrastructure/Notifications/FirebasePushSender.cs`

```csharp
namespace PartyPlan.Infrastructure.Notifications;

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Envoi réel des notifications, par FCM HTTP v1.
/// <para>
/// Scoped : la mise au rebut d'un jeton passe par <see cref="IPushDeviceRegistry"/>, lui
/// aussi scoped. Le cache du jeton d'accès est isolé dans <see cref="GoogleAccessTokens"/>,
/// singleton, sans quoi il serait vidé à chaque requête.
/// </para>
/// </summary>
public sealed class FirebasePushSender(
    ServiceAccountKey cle,
    GoogleAccessTokens jetons,
    HttpClient http,
    IPushDeviceRegistry appareils,
    ILogger<FirebasePushSender> logger) : IPushSender
{
    public bool IsConfigured => true;

    public async Task SendAsync(PushMessage message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);

        try
        {
            var acces = await jetons.ObtenirAsync(cle, cancellationToken).ConfigureAwait(false);

            if (acces is null)
            {
                // Déjà journalisé par GoogleAccessTokens : ne pas doubler le bruit.
                return;
            }

            using var requete = new HttpRequestMessage(
                HttpMethod.Post,
                new Uri($"https://fcm.googleapis.com/v1/projects/{cle.ProjectId}/messages:send"))
            {
                Headers = { Authorization = new("Bearer", acces) },
                Content = JsonContent.Create(Corps(message)),
            };

            using var reponse = await http
                .SendAsync(requete, cancellationToken)
                .ConfigureAwait(false);

            if (reponse.IsSuccessStatusCode)
            {
                return;
            }

            await TraiterEchecAsync(reponse, message, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception erreur) when (erreur is not OperationCanceledException)
        {
            // Aucune exception ne franchit cette frontière : une notification perdue ne
            // doit jamais faire échouer la dépense, l'achat ou l'invitation qui l'a
            // déclenchée.
            logger.LogError(
                erreur,
                "Notification non envoyée à l'appareil {Appareil}.",
                Tronquer(message.DeviceToken));
        }
    }

    /// <summary>
    /// Corps du message. Le lien profond voyage dans <c>data</c> et non dans
    /// <c>notification</c> : c'est le client qui décide quoi ouvrir, le système
    /// d'exploitation n'a pas à connaître nos routes.
    /// </summary>
    private static object Corps(PushMessage message) => message.DeepLink is null
        ? new
        {
            message = new
            {
                token = message.DeviceToken,
                notification = new { title = message.Title, body = message.Body },
            },
        }
        : new
        {
            message = new
            {
                token = message.DeviceToken,
                notification = new { title = message.Title, body = message.Body },
                data = new { deepLink = message.DeepLink },
            },
        };

    private async Task TraiterEchecAsync(
        HttpResponseMessage reponse,
        PushMessage message,
        CancellationToken cancellationToken)
    {
        var brut = await reponse.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        var code = CodeErreur(brut);

        // UNREGISTERED : application désinstallée ou données effacées. INVALID_ARGUMENT sur
        // ce chemin : jeton malformé. Dans les deux cas le jeton ne redeviendra jamais
        // valide, et le garder ferait échouer chaque envoi jusqu'à la fin des temps.
        if (code is "UNREGISTERED" or "INVALID_ARGUMENT")
        {
            logger.LogInformation(
                "Appareil {Appareil} mis au rebut par FCM : {Code}.",
                Tronquer(message.DeviceToken),
                code);

            await appareils
                .DisableAsync(message.DeviceToken, $"fcm:{code}", cancellationToken)
                .ConfigureAwait(false);

            return;
        }

        // Panne passagère : journalisée, sans rejeu. Le rejeu appartient à l'ordonnanceur
        // du lot 1.11, qui n'existe pas encore.
        logger.LogWarning(
            "FCM refuse la notification pour {Appareil} : {Statut} {Code}.",
            Tronquer(message.DeviceToken),
            (int)reponse.StatusCode,
            code ?? "sans code");
    }

    /// <summary>Code d'erreur FCM, cherché dans <c>error.details[].errorCode</c>.</summary>
    private static string? CodeErreur(string corps)
    {
        try
        {
            using var document = JsonDocument.Parse(corps);

            if (!document.RootElement.TryGetProperty("error", out var erreur))
            {
                return null;
            }

            if (erreur.TryGetProperty("details", out var details)
                && details.ValueKind == JsonValueKind.Array)
            {
                foreach (var detail in details.EnumerateArray())
                {
                    if (detail.TryGetProperty("errorCode", out var code)
                        && code.ValueKind == JsonValueKind.String)
                    {
                        return code.GetString();
                    }
                }
            }

            return erreur.TryGetProperty("status", out var statut)
                   && statut.ValueKind == JsonValueKind.String
                ? statut.GetString()
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>
    /// Le jeton d'appareil est tronqué : entier, il encombre le journal sans rien
    /// apprendre, et c'est une donnée d'identification (NF-SEC-03).
    /// </summary>
    private static string Tronquer(string jeton) =>
        jeton.Length <= 12 ? jeton : $"{jeton[..8]}…";
}
```

- [ ] **Étape 5 : lancer le test, vérifier qu'il passe**

Commande : `dotnet test api/tests/PartyPlan.UnitTests/PartyPlan.UnitTests.csproj --filter "FullyQualifiedName~FirebasePushSender"`
Attendu : 6 tests réussis.

- [ ] **Étape 6 : brancher l'enregistrement**

Dans `api/src/PartyPlan.Infrastructure/DependencyInjection.cs`, remplacer le bloc
« Notifications poussées » :

```csharp
        // Notifications poussées. L'émetteur réel n'est choisi que si une clé de compte de
        // service est lisible ; sinon les notifications sont journalisées (NF-DEV-04,
        // règle 5). Le choix est fait une fois, au démarrage.
        services.AddOptions<PushOptions>()
            .Bind(configuration.GetSection(PushOptions.SectionName))
            .ValidateOnStart();

        services.AddSingleton<ConsolePushSender>();
        services.AddSingleton<GoogleAccessTokens>();

        services.AddHttpClient(nameof(GoogleAccessTokens))
            .ConfigureHttpClient(client => client.Timeout = TimeSpan.FromSeconds(10));

        // Scoped : l'émetteur Firebase consomme IPushDeviceRegistry, qui est scoped.
        services.AddScoped<PartyPlan.SharedKernel.Contracts.IPushSender>(sp =>
        {
            var chemin = sp.GetRequiredService<IOptions<PushOptions>>()
                .Value.FirebaseServiceAccountPath;

            var cle = PushSenderFactory.CleUtilisable(
                chemin,
                sp.GetRequiredService<ILogger<GoogleAccessTokens>>());

            if (cle is null)
            {
                return sp.GetRequiredService<ConsolePushSender>();
            }

            return new FirebasePushSender(
                cle,
                sp.GetRequiredService<GoogleAccessTokens>(),
                sp.GetRequiredService<IHttpClientFactory>().CreateClient(nameof(GoogleAccessTokens)),
                sp.GetRequiredService<PartyPlan.SharedKernel.Contracts.IPushDeviceRegistry>(),
                sp.GetRequiredService<ILogger<FirebasePushSender>>());
        });
```

Vérifier que `using Microsoft.Extensions.Options;`, `using Microsoft.Extensions.Logging;` et
`using PartyPlan.Infrastructure.Notifications;` sont présents en tête de fichier.

`GoogleAccessTokens` prend un `HttpClient` en constructeur alors qu'il est singleton :
l'enregistrer par `AddSingleton<GoogleAccessTokens>()` échouerait. Le remplacer par :

```csharp
        services.AddSingleton(sp => new GoogleAccessTokens(
            sp.GetRequiredService<IHttpClientFactory>().CreateClient(nameof(GoogleAccessTokens)),
            sp.GetRequiredService<PartyPlan.SharedKernel.Abstractions.IClock>(),
            sp.GetRequiredService<ILogger<GoogleAccessTokens>>()));
```

- [ ] **Étape 7 : compiler et commiter**

La compilation réussit : `IPushDeviceRegistry` est résolu par le conteneur, et une
dépendance non enregistrée ne se manifeste qu'à l'exécution. Son implémentation arrive à la
tâche 4.

```bash
dotnet build api/PartyPlan.slnx
dotnet test api/PartyPlan.slnx
```
Attendu : compilation sans erreur ni avertissement ; tests unitaires verts.

Les tests d'intégration **échoueront** si l'un d'eux résout `IPushSender` avec une clé
configurée — ce n'est pas le cas, la fixture n'en pose aucune, donc `ConsolePushSender` est
choisi et `IPushDeviceRegistry` n'est jamais résolu. Si un test d'intégration échoue tout de
même sur cette dépendance, enchaîner la tâche 4 avant de commiter.

```bash
git add api/src/PartyPlan.SharedKernel/Contracts/IPushDeviceRegistry.cs \
        api/src/PartyPlan.Infrastructure api/tests/PartyPlan.UnitTests
git commit -m "feat(notifications): envoyer par FCM et mettre au rebut les jetons refusés"
```

---

### Tâche 4 : enregistrer et retirer un appareil

**Fichiers :**
- Créer : `api/src/PartyPlan.Modules.Notifications/Application/DeviceService.cs`
- Créer : `api/src/PartyPlan.Modules.Notifications/Endpoints/DeviceEndpoints.cs`
- Modifier : `api/src/PartyPlan.Modules.Notifications/NotificationsModule.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/AppareilsTests.cs`

**Interfaces :**
- Consomme : `IPushDeviceRegistry` (tâche 3), `INotificationsDbContext.PushDevices`
- Produit : `DeviceService` implémentant `IPushDeviceRegistry`, endpoints
  `POST /v1/me/devices` et `DELETE /v1/me/devices/{token}`

- [ ] **Étape 1 : écrire le test qui échoue**

`api/tests/PartyPlan.IntegrationTests/AppareilsTests.cs`

```csharp
namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Enregistrement des appareils recevant les notifications.
/// <para>
/// Un jeton FCM est renvoyé par le système à chaque lancement de l'application :
/// l'idempotence n'est pas un raffinement, c'est ce qui empêche <c>push_devices</c> de
/// grossir à chaque ouverture et chaque notification de partir en plusieurs exemplaires.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AppareilsTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    /// <summary>Jeton réaliste : un jeton FCM porte « : », « _ » et « - ».</summary>
    private const string Jeton =
        "fZ1pQw3kR0m:APA91bH_exemple-de-jeton-fcm_assez-long-pour-etre-realiste";

    [Fact]
    public async Task Un_appelant_anonyme_ne_peut_pas_enregistrer_d_appareil()
    {
        using var client = fixture.CreateClient();

        var reponse = await client.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = Jeton, platform = "android" });

        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Un_appareil_s_enregistre_puis_se_retire()
    {
        using var client = await ConnecteAsync();

        (await client.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = Jeton, platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CompterAsync(Jeton)).ShouldBe(1);

        (await client.DeleteAsync(new Uri($"/v1/me/devices/{Uri.EscapeDataString(Jeton)}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CompterAsync(Jeton)).ShouldBe(0);
    }

    [Fact]
    public async Task Un_reenregistrement_ne_cree_pas_un_second_appareil()
    {
        using var client = await ConnecteAsync();
        var jeton = $"{Jeton}-rejeu";

        for (var i = 0; i < 3; i++)
        {
            (await client.PostAsJsonAsync(
                    new Uri("/v1/me/devices", UriKind.Relative),
                    new { token = jeton, platform = "android" }))
                .StatusCode.ShouldBe(HttpStatusCode.NoContent);
        }

        (await CompterAsync(jeton)).ShouldBe(1);
    }

    [Fact]
    public async Task Un_jeton_deja_rattache_a_un_autre_compte_est_reaffecte()
    {
        var jeton = $"{Jeton}-pret";

        using var premier = await ConnecteAsync();
        await premier.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = jeton, platform = "android" });

        using var second = await ConnecteAsync();
        (await second.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = jeton, platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // Une seule ligne, rattachée au dernier compte : le téléphone prêté ne doit plus
        // recevoir les notifications de son précédent titulaire.
        (await CompterAsync(jeton)).ShouldBe(1);
    }

    [Fact]
    public async Task Une_plateforme_inconnue_est_refusee()
    {
        using var client = await ConnecteAsync();

        var reponse = await client.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = $"{Jeton}-blackberry", platform = "blackberry" });

        // Un fourre-tout non validé finit par contenir trois orthographes de la même
        // plateforme, et aucune requête ne sait plus les retrouver.
        reponse.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Un_jeton_vide_est_refuse()
    {
        using var client = await ConnecteAsync();

        (await client.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = "  ", platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Retirer_un_jeton_inconnu_reussit_sans_rien_faire()
    {
        using var client = await ConnecteAsync();

        // Idempotent : le client retire son jeton à la déconnexion, sans savoir si le
        // serveur le connaît. Un 404 le ferait échouer pour rien.
        (await client.DeleteAsync(new Uri("/v1/me/devices/jeton-jamais-vu", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<HttpClient> ConnecteAsync()
    {
        using var anonyme = fixture.CreateClient();
        var adresse = $"appareil-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasse, displayName = "Porteur" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            corps.GetProperty("accessToken").GetString());

        return client;
    }

    private async Task<int> CompterAsync(string jeton)
    {
        var compte = 0;

        await fixture.WithDatabaseAsync(async db =>
            compte = await db.PushDevices.CountAsync(a => a.Token == jeton));

        return compte;
    }
}
```

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj --filter "FullyQualifiedName~Appareils"`
Attendu : ÉCHEC — les endpoints répondent 404.

- [ ] **Étape 3 : écrire `DeviceService`**

`api/src/PartyPlan.Modules.Notifications/Application/DeviceService.cs`

```csharp
namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Appareils recevant les notifications poussées.
/// <para>
/// Implémente aussi <see cref="IPushDeviceRegistry"/>, contrat par lequel l'émetteur de
/// l'Infrastructure met un jeton au rebut sans écrire lui-même dans <c>push_devices</c>
/// (règle 6).
/// </para>
/// </summary>
public sealed class DeviceService(
    INotificationsDbContext db,
    ICurrentUser currentUser,
    IClock clock,
    IIdGenerator ids) : IPushDeviceRegistry
{
    /// <summary>Plateformes acceptées. iOS arrivera avec le portage, en V1.2.</summary>
    private static readonly string[] Plateformes = ["android", "web"];

    public static readonly DomainError JetonInvalide = DomainError.Validation(
        "device.token_required",
        "Le jeton de l'appareil est absent.");

    public static readonly DomainError PlateformeInconnue = DomainError.Validation(
        "device.unknown_platform",
        "Plateforme inconnue. Valeurs acceptées : android, web.");

    /// <summary>
    /// Enregistre l'appareil du compte appelant.
    /// <para>
    /// Idempotent sur le jeton, et réaffectant : un jeton FCM est renvoyé à chaque
    /// lancement, et le même téléphone peut changer de titulaire. Créer une ligne par
    /// appel enverrait la même notification plusieurs fois ; refuser la réaffectation
    /// laisserait les notifications d'un compte arriver chez quelqu'un d'autre.
    /// </para>
    /// </summary>
    public async Task<Result> EnregistrerAsync(
        string? token,
        string? platform,
        CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } utilisateur)
        {
            return DomainError.Unauthenticated("auth.required", "Session requise.");
        }

        if (string.IsNullOrWhiteSpace(token))
        {
            return JetonInvalide;
        }

        var plateforme = platform?.Trim().ToLowerInvariant();

        if (plateforme is null || !Plateformes.Contains(plateforme, StringComparer.Ordinal))
        {
            return PlateformeInconnue;
        }

        var jeton = token.Trim();

        var existant = await db.PushDevices
            .FirstOrDefaultAsync(a => a.Token == jeton, cancellationToken)
            .ConfigureAwait(false);

        if (existant is null)
        {
            db.PushDevices.Add(new PushDevice
            {
                Id = ids.NewId(),
                UserId = utilisateur,
                Token = jeton,
                Platform = plateforme,
                CreatedAt = clock.UtcNow,
                LastSeenAt = clock.UtcNow,
            });
        }
        else
        {
            existant.UserId = utilisateur;
            existant.Platform = plateforme;
            existant.LastSeenAt = clock.UtcNow;
            // Un appareil qui se réenregistre est un appareil vivant : la mise au rebut
            // précédente n'a plus lieu d'être.
            existant.DisabledAt = null;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Retire l'appareil. Réussit même si le jeton est inconnu : le client l'appelle à la
    /// déconnexion sans savoir ce que le serveur connaît, et un échec ici bloquerait la
    /// déconnexion pour rien.
    /// </summary>
    public async Task<Result> RetirerAsync(string token, CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } utilisateur)
        {
            return DomainError.Unauthenticated("auth.required", "Session requise.");
        }

        var appareil = await db.PushDevices
            .FirstOrDefaultAsync(
                a => a.Token == token && a.UserId == utilisateur,
                cancellationToken)
            .ConfigureAwait(false);

        if (appareil is not null)
        {
            db.PushDevices.Remove(appareil);
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        }

        return Result.Success();
    }

    /// <inheritdoc />
    public async Task DisableAsync(string token, string raison, CancellationToken cancellationToken)
    {
        // Pas de contrôle d'appelant : c'est FCM qui déclare le jeton mort, et la
        // désactivation n'expose rien.
        var appareil = await db.PushDevices
            .FirstOrDefaultAsync(a => a.Token == token, cancellationToken)
            .ConfigureAwait(false);

        if (appareil is null || appareil.DisabledAt is not null)
        {
            return;
        }

        appareil.DisabledAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }
}
```

Vérifier la signature exacte de `DomainError.Unauthenticated` :
`grep -n "Unauthenticated" api/src/PartyPlan.SharedKernel/Primitives/DomainError.cs`. Si la
fabrique porte un autre nom, l'ajuster.

- [ ] **Étape 4 : écrire les endpoints**

`api/src/PartyPlan.Modules.Notifications/Endpoints/DeviceEndpoints.cs`

```csharp
namespace PartyPlan.Modules.Notifications.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Notifications.Application;
using PartyPlan.SharedKernel.Http;

/// <summary>Appareil à inscrire pour recevoir les notifications.</summary>
public sealed record DeviceBody(
    [Required][MaxLength(4096)] string Token,
    [Required][MaxLength(20)] string Platform);

/// <summary>
/// Endpoints des appareils (§8.2).
/// <para>
/// Déclarés par le module Notifications et non par <c>MeEndpoints</c>, bien que la route
/// commence par « /me » : <c>push_devices</c> appartient à ce module, et la règle 6
/// interdit au module Users d'y toucher.
/// </para>
/// </summary>
internal static class DeviceEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/me/devices")
            .WithTags("Notifications")
            .RequireAuthorization();

        groupe.MapPost("/", async (
                DeviceBody corps,
                DeviceService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .EnregistrerAsync(corps.Token, corps.Platform, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("RegisterDevice")
            .WithSummary("Inscrit l'appareil courant. Idempotent sur le jeton.")
            .ProducesValidationProblem();

        groupe.MapDelete("/{token}", async (
                string token,
                DeviceService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .RetirerAsync(token, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UnregisterDevice")
            .WithSummary("Retire l'appareil. Réussit même si le jeton est inconnu.");
    }
}
```

- [ ] **Étape 5 : brancher le module**

`api/src/PartyPlan.Modules.Notifications/NotificationsModule.cs`

```csharp
namespace PartyPlan.Modules.Notifications;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Notifications.Application;
using PartyPlan.Modules.Notifications.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Notifications » (ADR 0002). Le transport est en place ; les déclencheurs
/// métier arrivent avec le reste du lot 1.11 de docs/roadmap.md.
/// </summary>
public sealed class NotificationsModule : IModule
{
    public string Name => "Notifications";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<DeviceService>();

        // Contrat public consommé par l'émetteur de l'Infrastructure, qui ne doit pas
        // écrire dans push_devices lui-même (règle 6).
        services.AddScoped<IPushDeviceRegistry>(sp => sp.GetRequiredService<DeviceService>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => DeviceEndpoints.Map(routes);
}
```

- [ ] **Étape 6 : lancer les tests, vérifier qu'ils passent**

Commande : `dotnet test api/tests/PartyPlan.IntegrationTests/PartyPlan.IntegrationTests.csproj --filter "FullyQualifiedName~Appareils"`
Attendu : 7 tests réussis.

- [ ] **Étape 7 : vérifier les frontières et l'ensemble**

```bash
make frontieres
make verif
```
Attendu : 11 modules, aucune violation ; toute la suite verte.

- [ ] **Étape 8 : commit**

```bash
git add api/src/PartyPlan.Modules.Notifications api/tests/PartyPlan.IntegrationTests/AppareilsTests.cs
git commit -m "feat(notifications): enregistrer et retirer un appareil"
```

---

### Tâche 5 : Android — greffon conditionnel et client Dart

**Fichiers :**
- Modifier : `app/pubspec.yaml`
- Modifier : `app/android/app/build.gradle.kts`
- Modifier : `app/android/settings.gradle.kts`
- Créer : `app/lib/core/network/appareils_api.dart`
- Modifier : `app/lib/core/providers.dart`
- Test : `app/test/core/appareils_api_test.dart`

**Interfaces :**
- Consomme : `POST /v1/me/devices`, `DELETE /v1/me/devices/{token}` (tâche 4)
- Produit : `AppareilsApi.enregistrer(String jeton, {required String plateforme})`,
  `AppareilsApi.retirer(String jeton)`, `appareilsApiProvider`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/appareils_api_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/appareils_api.dart';

import '../doubles/session_store_double.dart';

/// Le jeton part vers le serveur sans transformation : c'est le système qui l'a produit,
/// et le moindre découpage le rendrait inutilisable.
void main() {
  group('AppareilsApi', () {
    test('enregistre le jeton et la plateforme', () async {
      final appels = <(String, Object?)>[];
      final api = AppareilsApi(_client(appels));

      await api.enregistrer('fZ1p:APA91b_jeton', plateforme: 'android');

      expect(appels.single.$1, '/me/devices');
      expect(appels.single.$2, {
        'token': 'fZ1p:APA91b_jeton',
        'platform': 'android',
      });
    });

    test('retire le jeton en l’échappant dans le chemin', () async {
      final appels = <(String, Object?)>[];
      final api = AppareilsApi(_client(appels));

      // Un jeton FCM contient « : » : non échappé, il découperait le chemin.
      await api.retirer('fZ1p:APA91b_jeton');

      expect(appels.single.$1, '/me/devices/fZ1p%3AAPA91b_jeton');
    });
  });
}

ApiClient _client(List<(String, Object?)> appels) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        appels.add((options.path, options.data));
        handler.resolve(
          Response<Object?>(requestOptions: options, statusCode: 204),
        );
      },
    ),
  );

  return ApiClient(dio: dio, sessions: SessionStoreDouble());
}
```

Vérifier la signature réelle du constructeur d'`ApiClient` :
`grep -n "ApiClient(" -A8 app/lib/core/network/api_client.dart`, et l'adapter. S'inspirer
d'un test existant qui construit un `ApiClient` : `app/test/core/courses_client_test.dart`.

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `cd app && flutter test test/core/appareils_api_test.dart`
Attendu : ÉCHEC, `appareils_api.dart` introuvable.

- [ ] **Étape 3 : écrire le client**

`app/lib/core/network/appareils_api.dart`

```dart
import 'api_client.dart';

/// Appels d'API des appareils recevant les notifications.
///
/// Écrit à la main comme les autres clients du dépôt : deux endpoints ne justifient pas
/// une chaîne de génération.
class AppareilsApi {
  const AppareilsApi(this._client);

  final ApiClient _client;

  /// Inscrit l'appareil courant. Idempotent côté serveur : appelable à chaque lancement
  /// et à chaque rafraîchissement de jeton, sans précaution.
  Future<void> enregistrer(String jeton, {required String plateforme}) =>
      _client.post<void>(
        '/me/devices',
        corps: {'token': jeton, 'platform': plateforme},
        analyser: (_) {},
      );

  /// Retire l'appareil. Le jeton est échappé : un jeton FCM contient « : », qui
  /// découperait le chemin.
  Future<void> retirer(String jeton) =>
      _client.delete('/me/devices/${Uri.encodeComponent(jeton)}');
}
```

Corriger la coquille « Appels » dans le commentaire de tête au passage.

- [ ] **Étape 4 : ajouter le provider**

Dans `app/lib/core/providers.dart`, à la suite des autres providers d'API :

```dart
// ------------------------------------------------------------- notifications ----

final appareilsApiProvider = Provider<AppareilsApi>(
  (ref) => AppareilsApi(ref.watch(apiClientProvider)),
);
```

Ajouter l'import `import 'network/appareils_api.dart';`.

- [ ] **Étape 5 : lancer le test, vérifier qu'il passe**

Commande : `cd app && flutter test test/core/appareils_api_test.dart`
Attendu : 2 tests réussis.

- [ ] **Étape 6 : ajouter les dépendances Flutter**

Dans `app/pubspec.yaml`, section `dependencies` :

```yaml
  # Notifications poussées. Sans google-services.json ni configuration web, ces paquets
  # sont présents mais inertes : l'initialisation échoue proprement et l'application
  # fonctionne sans notifications (règle 5).
  firebase_core: ^4.1.1
  firebase_messaging: ^16.0.2
```

Puis `cd app && flutter pub get`. Si les versions ne résolvent pas avec Flutter 3.38,
prendre les dernières compatibles annoncées par `flutter pub get` et **noter les versions
retenues dans le message de commit**.

- [ ] **Étape 7 : rendre le greffon Google Services conditionnel**

Dans `app/android/settings.gradle.kts`, déclarer le greffon sans l'appliquer :

```kotlin
    id("com.google.gms.google-services") version "4.4.2" apply false
```

Dans `app/android/app/build.gradle.kts`, après le bloc `plugins { ... }` :

```kotlin
// Le greffon Google Services n'est appliqué que si google-services.json est présent.
//
// Le fichier est hors dépôt (NF-SEC-02, règle 5) : un clone frais doit compiler et
// tourner sans compte Firebase. Appliquer le greffon inconditionnellement ferait échouer
// la compilation avec « File google-services.json is missing », ce qui rendrait le dépôt
// inutilisable pour quiconque n'a pas le projet Firebase.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "google-services.json absent : compilation sans notifications poussées. " +
            "Voir docs/comptes-externes.md."
    )
}
```

- [ ] **Étape 8 : vérifier les deux compilations**

```bash
cd app
# Avec le fichier : le greffon s'applique.
flutter build apk --debug
# Sans : la compilation doit réussir et le message apparaître.
mv android/app/google-services.json /tmp/gs.json
flutter build apk --debug 2>&1 | grep "google-services.json absent"
mv /tmp/gs.json android/app/google-services.json
```
Attendu : les deux compilations réussissent, le message apparaît dans la seconde.

- [ ] **Étape 9 : `make verif` puis commit**

```bash
make verif
git add app/pubspec.yaml app/pubspec.lock app/android app/lib/core app/test/core/appareils_api_test.dart
git commit -m "feat(notifications): client d'enregistrement d'appareil et greffon Android conditionnel"
```

---

### Tâche 6 : demander le consentement, et retirer le jeton à la déconnexion

**Fichiers :**
- Créer : `app/lib/core/notifications/service_notifications.dart`
- Créer : `app/lib/features/evenement/sections/section_notifications.dart`
- Modifier : `app/lib/features/evenement/tableau_de_bord_page.dart`
- Modifier : `app/lib/core/providers.dart` (déconnexion)
- Test : `app/test/features/consentement_notifications_test.dart`

**Interfaces :**
- Consomme : `AppareilsApi`, `appareilsApiProvider` (tâche 5)
- Produit : `ServiceNotifications.demanderEtEnregistrer()`,
  `ServiceNotifications.retirerAppareilCourant()`, `serviceNotificationsProvider`,
  `SectionNotifications`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/features/consentement_notifications_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/sections/section_notifications.dart';

import '../aide/monter_ecran.dart';

/// RG-NOT-03 : le consentement est demandé au moment utile, pas au premier lancement.
///
/// Le moment utile est l'entrée dans une soirée : c'est là qu'on acquiert pour la
/// première fois quelque chose à être notifié. Demander au lancement fait refuser par
/// réflexe, et un refus système ne se redemande pas.
void main() {
  group('Consentement aux notifications', () {
    testWidgets('la section propose d’activer quand rien n’a été décidé', (
      tester,
    ) async {
      final service = _ServiceDouble(etat: EtatNotifications.aDemander);
      await _monter(tester, service);

      expect(find.textContaining('notification'), findsWidgets);
      expect(find.byKey(const Key('notifications-activer')), findsOneWidget);
    });

    testWidgets('rien ne s’affiche lorsque c’est déjà accordé', (tester) async {
      final service = _ServiceDouble(etat: EtatNotifications.accorde);
      await _monter(tester, service);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });

    testWidgets('un refus n’est plus redemandé', (tester) async {
      // Un refus système ne peut pas être redemandé par l'application : reproposer le
      // bouton donnerait un geste sans effet, ce qui est pire que ne rien proposer.
      final service = _ServiceDouble(etat: EtatNotifications.refuse);
      await _monter(tester, service);

      expect(find.byKey(const Key('notifications-activer')), findsNothing);
    });

    testWidgets('appuyer demande la permission et enregistre le jeton', (
      tester,
    ) async {
      final service = _ServiceDouble(etat: EtatNotifications.aDemander);
      await _monter(tester, service);

      await tester.tap(find.byKey(const Key('notifications-activer')));
      await tester.pumpAndSettle();

      expect(service.demandes, 1);
    });
  });
}

Future<void> _monter(WidgetTester tester, ServiceNotifications service) async {
  final conteneur = ProviderContainer(
    overrides: [serviceNotificationsProvider.overrideWithValue(service)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: SectionNotifications()),
    conteneur: conteneur,
  );
}

class _ServiceDouble implements ServiceNotifications {
  _ServiceDouble({required this.etat});

  final EtatNotifications etat;
  int demandes = 0;

  @override
  Future<EtatNotifications> etatCourant() async => etat;

  @override
  Future<void> demanderEtEnregistrer() async => demandes++;

  @override
  Future<void> retirerAppareilCourant() async {}

  @override
  Future<void> ecouterRafraichissements() async {}

  @override
  Future<void> ecouterOuvertures(void Function(String destination) aller) async {}
}
```

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `cd app && flutter test test/features/consentement_notifications_test.dart`
Attendu : ÉCHEC, `service_notifications.dart` introuvable.

- [ ] **Étape 3 : écrire le service**

`app/lib/core/notifications/service_notifications.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/appareils_api.dart';

/// Où en est le consentement de cette personne.
enum EtatNotifications {
  /// Rien n'a été demandé : c'est le seul cas où l'on propose quelque chose.
  aDemander,

  accorde,

  /// Refusé au niveau système. L'application ne peut pas redemander : reproposer le
  /// geste donnerait un bouton sans effet.
  refuse,

  /// Firebase n'est pas configuré sur cette compilation. Aucune notification n'est
  /// possible, et il n'y a rien à proposer (règle 5).
  indisponible,
}

/// Notifications poussées, côté application.
///
/// Une interface plutôt qu'une classe concrète : les écrans se testent sans Firebase,
/// qui exige une plateforme réelle et une configuration de projet.
abstract interface class ServiceNotifications {
  Future<EtatNotifications> etatCourant();

  /// Demande la permission puis enregistre le jeton. Sans effet si déjà refusé.
  Future<void> demanderEtEnregistrer();

  /// Retire l'appareil courant. À appeler **avant** de purger la session, sinon l'appel
  /// n'est plus authentifié.
  Future<void> retirerAppareilCourant();

  /// Réenregistre le jeton à chaque rotation. FCM en change sans prévenir, et un jeton
  /// périmé est une personne qui ne reçoit plus rien, sans erreur visible.
  Future<void> ecouterRafraichissements();

  /// Ouvre la destination portée par une notification tapée.
  ///
  /// Déclarée ici dès maintenant, implémentée à la tâche 7 : c'est l'interface que les
  /// écrans voient, et la compléter plus tard casserait toutes les doublures de test.
  Future<void> ecouterOuvertures(void Function(String destination) aller);
}

/// Implémentation Firebase.
///
/// Toute opération est sans effet si l'initialisation a échoué : c'est le cas d'un clone
/// sans `google-services.json`, qui doit rester utilisable (règle 5).
class ServiceNotificationsFirebase implements ServiceNotifications {
  ServiceNotificationsFirebase(this._api);

  final AppareilsApi _api;

  bool? _disponible;

  Future<bool> _initialiser() async {
    if (_disponible != null) {
      return _disponible!;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _disponible = true;
    } on Exception {
      // Aucune configuration Firebase dans cette compilation. Ce n'est pas une erreur.
      _disponible = false;
    }

    return _disponible!;
  }

  @override
  Future<EtatNotifications> etatCourant() async {
    if (!await _initialiser()) {
      return EtatNotifications.indisponible;
    }

    final reglages = await FirebaseMessaging.instance.getNotificationSettings();

    return switch (reglages.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => EtatNotifications.accorde,
      AuthorizationStatus.denied => EtatNotifications.refuse,
      _ => EtatNotifications.aDemander,
    };
  }

  @override
  Future<void> demanderEtEnregistrer() async {
    if (!await _initialiser()) {
      return;
    }

    final reglages = await FirebaseMessaging.instance.requestPermission();

    if (reglages.authorizationStatus != AuthorizationStatus.authorized
        && reglages.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    await _envoyerJeton();
  }

  @override
  Future<void> ecouterRafraichissements() async {
    if (!await _initialiser()) {
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((jeton) async {
      try {
        await _api.enregistrer(jeton, plateforme: _plateforme);
      } on Exception {
        // Le jeton repartira au prochain lancement : échouer ici ne doit rien
        // interrompre.
      }
    });
  }

  @override
  Future<void> retirerAppareilCourant() async {
    if (!await _initialiser()) {
      return;
    }

    try {
      final jeton = await FirebaseMessaging.instance.getToken();
      if (jeton != null) {
        await _api.retirer(jeton);
      }
    } on Exception {
      // Une déconnexion ne doit jamais échouer à cause d'une notification.
    }
  }

  Future<void> _envoyerJeton() async {
    try {
      final jeton = await FirebaseMessaging.instance.getToken();
      if (jeton != null) {
        await _api.enregistrer(jeton, plateforme: _plateforme);
      }
    } on Exception {
      // Sans effet visible : la personne a accordé la permission, le jeton repartira au
      // prochain lancement.
    }
  }

  @override
  Future<void> ecouterOuvertures(void Function(String destination) aller) async {
    // Implémentée à la tâche 7, avec la validation du lien. Déclarée vide ici pour que
    // l'interface soit complète et les doublures de test stables.
  }

  static String get _plateforme => kIsWeb ? 'web' : 'android';
}
```

- [ ] **Étape 4 : écrire la section**

`app/lib/features/evenement/sections/section_notifications.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/service_notifications.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';

/// Proposition d'activer les notifications — `RG-NOT-03`.
///
/// Placée sur le tableau de bord d'un événement, et nulle part ailleurs : c'est là qu'on
/// vient d'acquérir quelque chose à être notifié. Demander au premier lancement fait
/// refuser par réflexe, et un refus système ne se redemande pas.
///
/// La section disparaît dès que la question est tranchée, dans un sens ou dans l'autre.
class SectionNotifications extends ConsumerStatefulWidget {
  const SectionNotifications({super.key});

  @override
  ConsumerState<SectionNotifications> createState() => _SectionNotificationsState();
}

class _SectionNotificationsState extends ConsumerState<SectionNotifications> {
  EtatNotifications? _etat;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    final etat = await ref.read(serviceNotificationsProvider).etatCourant();
    if (mounted) {
      setState(() => _etat = etat);
    }
  }

  Future<void> _activer() async {
    await ref.read(serviceNotificationsProvider).demanderEtEnregistrer();
    await _lire();
  }

  @override
  Widget build(BuildContext context) {
    if (_etat != EtatNotifications.aDemander) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Être prévenu', style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.xs),
            Text(
              'Un changement de date, une réponse, un message : '
              'on te le fait savoir sans que tu aies à revenir voir.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('notifications-activer'),
                onPressed: _activer,
                child: const Text('Activer les notifications'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Vérifier le nom réel du composant carte : `ls app/lib/design/components/ | grep card`, et
adapter l'import et l'usage.

- [ ] **Étape 5 : brancher le provider et la section**

Dans `app/lib/core/providers.dart`, après `appareilsApiProvider` :

```dart
final serviceNotificationsProvider = Provider<ServiceNotifications>(
  (ref) => ServiceNotificationsFirebase(ref.watch(appareilsApiProvider)),
);
```

Ajouter `import 'notifications/service_notifications.dart';`.

Dans `app/lib/features/evenement/tableau_de_bord_page.dart`, ajouter l'import
`import 'sections/section_notifications.dart';` et insérer la section juste après
`SectionIdentite` :

```dart
            SectionIdentite(resume: resume),
            const SectionNotifications(),
```

- [ ] **Étape 6 : retirer le jeton à la déconnexion**

Dans `app/lib/core/providers.dart`, méthode `deconnecter()` de `SessionCourante`, **avant**
l'appel à `comptesApi.deconnecter()` :

```dart
    // Avant de purger la session : l'appel exige encore d'être authentifié. Un téléphone
    // rendu ou prêté ne doit plus recevoir les notifications de son ancien titulaire.
    await ref.read(serviceNotificationsProvider).retirerAppareilCourant();
```

- [ ] **Étape 7 : lancer les tests, vérifier qu'ils passent**

Commande : `cd app && flutter test test/features/consentement_notifications_test.dart`
Attendu : 4 tests réussis.

Puis vérifier qu'aucun test existant ne casse — `deconnexion_test.dart` monte la session :

```bash
cd app && flutter test
```
Si `deconnexion_test.dart` échoue faute de `serviceNotificationsProvider`, y ajouter un
doublon inerte de `_ServiceDouble` plutôt que de retirer l'appel : la déconnexion doit bien
retirer le jeton, c'est le test qui doit le savoir.

- [ ] **Étape 8 : `make verif` puis commit**

```bash
make verif
git add app/lib app/test
git commit -m "feat(notifications): demander le consentement à l'entrée d'une soirée"
```

---

### Tâche 7 : ouvrir le lien profond au tap

**Fichiers :**
- Créer : `app/lib/core/notifications/lien_notification.dart`
- Modifier : `app/lib/app/app.dart` (ou le point de montage du routeur)
- Test : `app/test/core/lien_notification_test.dart`

**Interfaces :**
- Consomme : `PpRoutes`, le routeur `go_router`
- Produit : `LienNotification.destination(Map<String, dynamic>? donnees) → String?`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/lien_notification_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/lien_notification.dart';

/// Le lien porté par une notification vient de l'extérieur : il est traité comme une
/// entrée non fiable, exactement comme le « retour » d'invitation l'est déjà.
void main() {
  group('LienNotification.destination', () {
    test('une route interne est conservée', () {
      expect(
        LienNotification.destination({'deepLink': '/events/42'}),
        '/events/42',
      );
    });

    test('des données absentes ne donnent aucune destination', () {
      expect(LienNotification.destination(null), isNull);
      expect(LienNotification.destination({}), isNull);
    });

    test('une adresse absolue est rejetée', () {
      // Sans ce refus, une notification forgée ouvrirait un site tiers dans l'application.
      expect(
        LienNotification.destination({'deepLink': 'https://exemple.fr/phishing'}),
        isNull,
      );
    });

    test('un préfixe protocole-relatif est rejeté', () {
      expect(
        LienNotification.destination({'deepLink': '//exemple.fr'}),
        isNull,
      );
    });

    test('un chemin sans barre initiale est rejeté', () {
      expect(LienNotification.destination({'deepLink': 'events/42'}), isNull);
    });
  });
}
```

- [ ] **Étape 2 : lancer le test, vérifier qu'il échoue**

Commande : `cd app && flutter test test/core/lien_notification_test.dart`
Attendu : ÉCHEC, `lien_notification.dart` introuvable.

- [ ] **Étape 3 : écrire la validation**

`app/lib/core/notifications/lien_notification.dart`

```dart
/// Destination d'une notification.
///
/// Le lien vient de l'extérieur : il est validé comme tel. Le même raisonnement que pour
/// le paramètre « retour » d'une invitation — une adresse absolue, une autorité ou un
/// préfixe « // » ouvrirait un site tiers à l'intérieur de l'application.
abstract final class LienNotification {
  static String? destination(Map<String, dynamic>? donnees) {
    final brut = donnees?['deepLink'];

    if (brut is! String || brut.isEmpty) {
      return null;
    }

    // Une route interne commence par une seule barre. « // » désigne une autorité.
    if (!brut.startsWith('/') || brut.startsWith('//')) {
      return null;
    }

    return brut;
  }
}
```

- [ ] **Étape 4 : lancer le test, vérifier qu'il passe**

Commande : `cd app && flutter test test/core/lien_notification_test.dart`
Attendu : 5 tests réussis.

- [ ] **Étape 5 : implémenter l'écoute dans le service**

Firebase n'est jamais appelé depuis un écran : sinon les tests d'application exigeraient une
plateforme réelle et un projet configuré. Tout passe par le service, déjà substituable.

Remplacer le corps vide de `ecouterOuvertures` dans `ServiceNotificationsFirebase` :

```dart
  @override
  Future<void> ecouterOuvertures(void Function(String destination) aller) async {
    if (!await _initialiser()) {
      return;
    }

    // Deux chemins, et le second est celui qu'on oublie : l'application déjà lancée reçoit
    // par onMessageOpenedApp ; l'application démarrée *par* la notification ne reçoit rien
    // et doit interroger getInitialMessage. C'est pourtant le cas d'un rappel reçu la
    // veille, donc le plus fréquent.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final destination = LienNotification.destination(message.data);
      if (destination != null) {
        aller(destination);
      }
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final destination = LienNotification.destination(initial?.data);
    if (destination != null) {
      aller(destination);
    }
  }
```

Ajouter l'import `import 'lien_notification.dart';`.

- [ ] **Étape 6 : brancher au routeur**

Lire d'abord le point de montage : `sed -n '1,60p' app/lib/app/app.dart`.

Dans `PartyPlanApp`, après l'obtention du routeur, poser l'écoute une seule fois. Un
`StatefulWidget` ou un `initState` existant convient ; ne pas la poser dans `build`, qui est
rappelé à chaque reconstruction et empilerait les abonnements.

```dart
    // Une seule fois : posée dans build, l'écoute s'empilerait à chaque reconstruction et
    // une notification tapée provoquerait autant de navigations.
    ref.read(serviceNotificationsProvider)
      ..ecouterRafraichissements()
      ..ecouterOuvertures(routeur.go);
```

`ecouterRafraichissements` et `ecouterOuvertures` renvoient des `Future` non attendues :
c'est voulu, l'application ne doit pas retarder son premier affichage pour cela. Ajouter
`// ignore: discarded_futures` si `flutter analyze` le réclame.

- [ ] **Étape 7 : `make verif` puis commit**

```bash
make verif
git add app/lib app/test
git commit -m "feat(notifications): ouvrir le lien profond porté par une notification"
```

---

### Tâche 8 : le Web

**Débloquée le 24/08/2026** : la clé VAPID est engendrée, et vérifiée conforme — 87
caractères, 65 octets décodés, préfixe `0x04`, soit une clé publique P-256 non compressée.
Sa valeur figure au tableau de l'étape 3. Elle n'est pas secrète : elle est publique dans
toute application web livrée.

**Fichiers :**
- Créer : `app/web/firebase-messaging-sw.js.template`
- Modifier : `app/Dockerfile`, `app/nginx.conf`, `.github/workflows/docker.yml`
- Modifier : `app/lib/core/notifications/service_notifications.dart`

- [ ] **Étape 1 : écrire le gabarit du service worker**

`app/web/firebase-messaging-sw.js.template`

```javascript
// Service worker des notifications web.
//
// Engendré à la compilation depuis ce gabarit : un service worker ne peut pas lire un
// --dart-define, et deux sources de configuration divergeraient au premier changement.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '__FIREBASE_API_KEY__',
  projectId: '__FIREBASE_PROJECT_ID__',
  messagingSenderId: '__FIREBASE_SENDER_ID__',
  appId: '__FIREBASE_APP_ID__',
});

firebase.messaging();
```

- [ ] **Étape 2 : substituer à la compilation**

Dans `app/Dockerfile`, après les `ARG` existants :

```dockerfile
# Configuration Firebase du Web. Ces valeurs ne sont pas des secrets : elles sont
# publiques dans toute application web livrée, et la clé d'API est restreinte par domaine.
# Vides par défaut : l'image compile sans Firebase, et l'application tourne sans
# notifications (règle 5).
ARG FIREBASE_API_KEY=""
ARG FIREBASE_PROJECT_ID=""
ARG FIREBASE_SENDER_ID=""
ARG FIREBASE_APP_ID=""
ARG FIREBASE_VAPID_KEY=""
```

Avant `RUN flutter build web`, engendrer le service worker :

```dockerfile
# Le service worker n'est engendré que si la configuration est fournie : sans lui, le
# navigateur n'enregistre aucun appareil et l'application fonctionne sans notifications.
RUN if [ -n "$FIREBASE_API_KEY" ]; then \
      sed -e "s|__FIREBASE_API_KEY__|$FIREBASE_API_KEY|" \
          -e "s|__FIREBASE_PROJECT_ID__|$FIREBASE_PROJECT_ID|" \
          -e "s|__FIREBASE_SENDER_ID__|$FIREBASE_SENDER_ID|" \
          -e "s|__FIREBASE_APP_ID__|$FIREBASE_APP_ID|" \
          web/firebase-messaging-sw.js.template > web/firebase-messaging-sw.js ; \
    else \
      echo "Configuration Firebase absente : compilation web sans notifications." ; \
    fi
```

et compléter la commande de compilation :

```dockerfile
RUN flutter build web \
      --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
      --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
      --dart-define=FIREBASE_SENDER_ID=${FIREBASE_SENDER_ID} \
      --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
      --dart-define=FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY}
```

- [ ] **Étape 3 : passer les valeurs depuis le CI**

Dans `.github/workflows/docker.yml`, aux **deux** blocs `build-args` (publication et pull
request), ajouter sous `API_BASE_URL=…` :

```yaml
            FIREBASE_API_KEY=${{ vars.FIREBASE_API_KEY }}
            FIREBASE_PROJECT_ID=${{ vars.FIREBASE_PROJECT_ID }}
            FIREBASE_SENDER_ID=${{ vars.FIREBASE_SENDER_ID }}
            FIREBASE_APP_ID=${{ vars.FIREBASE_APP_ID }}
            FIREBASE_VAPID_KEY=${{ vars.FIREBASE_VAPID_KEY }}
```

Valeurs à poser dans les *variables* du dépôt (pas les secrets : elles sont publiques) :

| Variable | Valeur |
|---|---|
| `FIREBASE_PROJECT_ID` | `partyplan-99106` |
| `FIREBASE_SENDER_ID` | `146275272251` |
| `FIREBASE_API_KEY` | `AIzaSyB2xKkcJzbRmCaXy6nmJ5BwEWPpGlSbiwo` |
| `FIREBASE_APP_ID` | `1:146275272251:web:a79c8ea920420da96afe1e` |
| `FIREBASE_VAPID_KEY` | `BFzPW6BjyMHmeN620Kb3EwtozHI9sEW-OwUH1Cs86JEw2meseAwl72KgqpuB9D596p16v-39XVqFtea7pBj8qZQ` |

- [ ] **Étape 4 : servir le service worker sans cache**

Dans `app/nginx.conf`, à côté du bloc `flutter_service_worker.js` :

```nginx
    # Même raison que pour flutter_service_worker.js : un service worker figé en cache
    # est un service worker qu'on ne peut plus corriger.
    location = /firebase-messaging-sw.js {
        add_header Cache-Control "no-cache, must-revalidate" always;
        include /etc/nginx/nginx-securite.conf;
    }
```

- [ ] **Étape 5 : initialiser Firebase côté Web**

Dans `service_notifications.dart`, `_initialiser()` doit fournir les options explicitement
sur le Web — `Firebase.initializeApp()` sans argument échoue faute de
`firebase_options.dart`. Remplacer le corps du `try` par :

```dart
      if (Firebase.apps.isEmpty) {
        const cle = String.fromEnvironment('FIREBASE_API_KEY');

        if (cle.isEmpty) {
          // Compilation sans configuration Firebase : rien à initialiser.
          _disponible = false;
          return false;
        }

        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: cle,
            projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
            messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
            appId: String.fromEnvironment('FIREBASE_APP_ID'),
          ),
        );
      }
```

et passer la clé VAPID à `getToken` sur le Web :

```dart
  Future<String?> _jetonCourant() => kIsWeb
      ? FirebaseMessaging.instance.getToken(
          vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
        )
      : FirebaseMessaging.instance.getToken();
```

Remplacer les deux appels à `FirebaseMessaging.instance.getToken()` par `_jetonCourant()`.

Sur Android, `Firebase.initializeApp()` lit `google-services.json` et n'a pas besoin
d'options : la branche `String.fromEnvironment` vide y renverrait faussement
« indisponible ». Garder donc `!kIsWeb` sur le chemin sans options.

- [ ] **Étape 6 : vérifier les deux compilations web**

```bash
cd app
docker build -t pp-web-sans .
docker build -t pp-web-avec \
  --build-arg FIREBASE_API_KEY=AIzaSyB2xKkcJzbRmCaXy6nmJ5BwEWPpGlSbiwo \
  --build-arg FIREBASE_PROJECT_ID=partyplan-99106 \
  --build-arg FIREBASE_SENDER_ID=146275272251 \
  --build-arg FIREBASE_APP_ID=1:146275272251:web:a79c8ea920420da96afe1e \
  --build-arg FIREBASE_VAPID_KEY=BFzPW6BjyMHmeN620Kb3EwtozHI9sEW-OwUH1Cs86JEw2meseAwl72KgqpuB9D596p16v-39XVqFtea7pBj8qZQ .
docker run --rm pp-web-avec ls /usr/share/nginx/html/firebase-messaging-sw.js
docker run --rm pp-web-sans ls /usr/share/nginx/html/ | grep -c firebase-messaging || true
```
Attendu : les deux images se construisent ; le fichier n'existe que dans la seconde.

- [ ] **Étape 7 : `make verif` puis commit**

```bash
make verif
git add app .github/workflows/docker.yml
git commit -m "feat(notifications): notifications web, service worker engendré à la compilation"
```

---

### Tâche 9 : configuration, documentation, feuille de route

**Fichiers :**
- Modifier : `.env.example`, `infra/compose/.env.example`
- Modifier : `infra/compose/compose.yml`, `compose.example.yml`, `compose.nas.example.yml`
- Modifier : `docs/comptes-externes.md`, `docs/exploitation.md`, `docs/roadmap.md`
- Modifier : `docs/api/openapi.json`

- [ ] **Étape 1 : déclarer la variable**

Dans `.env.example` et `infra/compose/.env.example` :

```bash
# ---------- Notifications poussées ----------
# Chemin du fichier de clé de compte de service Firebase. Vide en développement : les
# notifications sont alors journalisées en console, et rien ne part (NF-DEV-04).
# Obtention : voir docs/comptes-externes.md §Firebase.
FIREBASE_SERVICE_ACCOUNT_PATH=
```

- [ ] **Étape 2 : les trois fichiers compose**

`infra/compose/compose.yml` et `compose.example.yml`, service `api` :

```yaml
      Push__FirebaseServiceAccountPath: ${FIREBASE_SERVICE_ACCOUNT_PATH:-}
```

`infra/compose/compose.nas.example.yml` — pas de fichier `.env` sur le NAS, les valeurs se
remplacent en place :

```yaml
      # ---------- Notifications poussées ----------
      # Déposer le fichier de clé remis par Firebase dans ./secrets/firebase.json à côté
      # de ce compose, sans le retoucher. Le laisser absent est un choix valable : les
      # notifications sont alors journalisées et rien ne part.
      Push__FirebaseServiceAccountPath: /run/secrets/firebase.json
```

et dans le même service :

```yaml
    volumes:
      - ./secrets/firebase.json:/run/secrets/firebase.json:ro
```

Vérifier si le service `api` a déjà un bloc `volumes` et compléter plutôt que d'en créer un
second.

- [ ] **Étape 3 : `make variables`**

```bash
./tools/verifier-variables-env.sh
```
Attendu : aucune variable déclarée non lue, toutes les clés lues déclarées.

- [ ] **Étape 4 : documenter l'obtention**

Ajouter une section à `docs/comptes-externes.md` : projet `partyplan-99106`, enregistrement
des deux applications, `firebase apps:sdkconfig ANDROID … --out app/android/app/google-services.json`,
`gcloud iam service-accounts keys create … --iam-account=firebase-adminsdk-fbsvc@partyplan-99106.iam.gserviceaccount.com`,
et le passage en console pour la clé VAPID. Préciser que ces trois fichiers sont hors dépôt.

Dans `docs/exploitation.md`, ajouter au tableau des secrets :

| `./secrets/firebase.json` | Clé remise par Firebase, déposée telle quelle. Sa perte : régénérer une clé, les anciennes se révoquent dans la console |

- [ ] **Étape 5 : régénérer le contrat**

```bash
make api    # dans un autre terminal
make openapi
```
Vérifier que le diff n'ajoute que `/v1/me/devices` et `DeviceBody`.

- [ ] **Étape 6 : mettre la feuille de route à jour**

Dans `docs/roadmap.md`, lot 1.11, ajouter en tête de section :

```markdown
**Transport livré le 24/08/2026** — `ADR`-libre, voir
`docs/superpowers/specs/2026-08-24-notifications-transport-firebase-design.md`. Une
notification part du serveur et arrive sur un appareil. **Aucun déclencheur n'est branché :
personne ne reçoit rien tant que les lignes ci-dessous ne sont pas cochées.** C'est écrit
ici parce qu'un transport livré donne l'impression d'un lot fait.

- [x] Enregistrement des appareils, `POST`/`DELETE /v1/me/devices`, idempotent et réaffectant
- [x] Émetteur FCM HTTP v1, sans dépendance nouvelle ; repli console sans clé (règle 5)
- [x] Mise au rebut des jetons refusés par FCM
- [x] Consentement demandé à l'entrée dans une soirée (`RG-NOT-03`)
- [x] Ouverture du lien profond au tap, application lancée ou démarrée par la notification
```

et laisser décochées les lignes `EF-NOT-01` à `EF-NOT-09`, `RG-NOT-01`, `RG-NOT-02` et
l'ordonnanceur.

- [ ] **Étape 7 : `make verif` puis commit**

```bash
make verif
git add .env.example infra docs
git commit -m "docs(notifications): documenter et configurer le transport"
```

---

## Vérification finale, avec un vrai téléphone

Aucun test ne remplace celle-ci.

- [ ] Déposer la clé, démarrer l'API, vérifier au journal que `FirebasePushSender` est
      choisi et non `ConsolePushSender`
- [ ] Lancer l'application Android, entrer dans une soirée, accepter la permission
- [ ] Vérifier en base : `select platform, disabled_at from push_devices;` → une ligne
      `android`, `disabled_at` nul
- [ ] Envoyer une notification de test depuis un script jetable appelant `IPushSender`, avec
      un lien profond vers l'événement
- [ ] Constater l'arrivée sur le téléphone, application au premier plan
- [ ] Recommencer application fermée, puis **taper la notification** et vérifier que
      l'événement s'ouvre
- [ ] Désinstaller l'application, renvoyer une notification, vérifier que `disabled_at` se
      pose
