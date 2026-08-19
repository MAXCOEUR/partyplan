namespace PartyPlan.Modules.Auth.Application;

using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;

/// <summary>Options d'émission des jetons.</summary>
public sealed class TokenOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; set; } = string.Empty;

    public string Audience { get; set; } = string.Empty;

    public string SigningKey { get; set; } = string.Empty;

    /// <summary>
    /// Durée du jeton d'accès. Courte volontairement : c'est le jeton exposé à chaque
    /// requête, et la révocation d'une session ne peut agir qu'à son renouvellement.
    /// </summary>
    public int AccessTokenMinutes { get; set; } = 15;

    /// <summary>Durée de la session, prolongée à chaque usage (EF-AUTH-09).</summary>
    public int RefreshTokenDays { get; set; } = 90;

    /// <summary>Validité d'un lien envoyé par courriel (RG-AUTH-03).</summary>
    public int OneTimeSecretMinutes { get; set; } = 15;
}

/// <summary>
/// Émission des jetons.
/// <para>
/// Les jetons de rafraîchissement et les liens à usage unique ne sont jamais stockés en
/// clair : seul leur condensé SHA-256 est conservé. Une fuite de la base ne permet donc
/// pas de rejouer une session ni de consommer un lien de réinitialisation.
/// </para>
/// </summary>
public sealed class TokenService(IOptions<TokenOptions> options, IClock clock) : ITokenService
{
    /// <summary>Revendications propres au produit.</summary>
    public const string PlatformRoleClaim = "pp:platform_role";

    public const string GuestEventClaim = "pp:guest_event";

    public const string SessionClaim = "pp:session";

    public const string MemberClaim = "pp:member";

    private TokenOptions Options => options.Value;

    public AccessToken CreateAccessToken(Guid userId, PlatformRole role, Guid sessionId) =>
        Create(
        [
            new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(PlatformRoleClaim, role.ToString()),
            new Claim(SessionClaim, sessionId.ToString()),
        ]);

    public AccessToken CreateGuestToken(Guid eventId, Guid memberId) =>
        Create(
        [
            // Aucun identifiant de compte : un invité n'en a pas, et lui en attribuer un
            // ouvrirait son périmètre au-delà de l'événement rejoint.
            new Claim(JwtRegisteredClaimNames.Sub, $"guest:{memberId}"),
            new Claim(GuestEventClaim, eventId.ToString()),
            new Claim(MemberClaim, memberId.ToString()),
            new Claim(PlatformRoleClaim, nameof(PlatformRole.User)),
        ]);

    public RefreshToken CreateRefreshToken()
    {
        var valeur = GenerateSecret();

        return new RefreshToken(
            valeur,
            Hash(valeur),
            clock.UtcNow.AddDays(Options.RefreshTokenDays));
    }

    public string HashRefreshToken(string plainToken) => Hash(plainToken);

    public OneTimeSecret CreateOneTimeSecret()
    {
        var valeur = GenerateSecret();

        return new OneTimeSecret(
            valeur,
            Hash(valeur),
            clock.UtcNow.AddMinutes(Options.OneTimeSecretMinutes));
    }

    /// <summary>256 bits d'entropie, encodés en base64url : au-delà de l'exigence de RG-INV-01.</summary>
    private static string GenerateSecret() =>
        Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(32));

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private AccessToken Create(Claim[] claims)
    {
        var expiration = clock.UtcNow.AddMinutes(Options.AccessTokenMinutes);

        var descripteur = new SecurityTokenDescriptor
        {
            Issuer = Options.Issuer,
            Audience = Options.Audience,
            Subject = new ClaimsIdentity(claims),
            NotBefore = clock.UtcNow.UtcDateTime,
            Expires = expiration.UtcDateTime,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Options.SigningKey)),
                SecurityAlgorithms.HmacSha256),
        };

        return new AccessToken(new JsonWebTokenHandler().CreateToken(descripteur), expiration);
    }
}

/// <summary>Noms de revendications normalisées, pour éviter une dépendance supplémentaire.</summary>
internal static class JwtRegisteredClaimNames
{
    internal const string Sub = "sub";
}
