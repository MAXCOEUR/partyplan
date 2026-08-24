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
    ILogger<GoogleAccessTokens> logger) : IDisposable
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

    /// <summary>Libère le verrou. Sans effet sur le <see cref="HttpClient"/>, qui n'est pas
    /// possédé par cette classe : il est injecté et son cycle de vie appartient au
    /// conteneur (<c>IHttpClientFactory</c> ou équivalent).</summary>
    public void Dispose() => _verrou.Dispose();

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
