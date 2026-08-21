namespace PartyPlan.IntegrationTests.Infrastructure;

using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using PartyPlan.Infrastructure.Identity;
using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Émission de jetons de test. Les jetons sont signés avec la même clé que l'hôte et
/// traversent la validation réelle : les tests franchissent donc la chaîne
/// d'authentification complète, et non un raccourci.
/// </summary>
internal static class TestTokens
{
    private const string LegacyGuestEventClaim = "pp:guest_event";

    private const string LegacyMemberClaim = "pp:member";

    internal static string ForUser(Guid userId, PlatformRole role = PlatformRole.User)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Subject, userId.ToString()),
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(PartyPlanClaims.PlatformRole, role.ToString()),
        };

        return Create(claims);
    }

    /// <summary>Reproduit un ancien jeton signé afin de vérifier qu'il reste refusé.</summary>
    internal static string ForLegacyGuest(Guid eventId, Guid memberId)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Subject, $"guest:{memberId}"),
            new(LegacyGuestEventClaim, eventId.ToString()),
            new(LegacyMemberClaim, memberId.ToString()),
            new(PartyPlanClaims.PlatformRole, nameof(PlatformRole.User)),
        };

        return Create(claims);
    }

    private static string Create(IEnumerable<Claim> claims)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(PartyPlanApiFixture.SigningKey));
        var token = new JwtSecurityToken(
            issuer: PartyPlanApiFixture.Issuer,
            audience: PartyPlanApiFixture.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow.AddMinutes(-1),
            expires: DateTime.UtcNow.AddMinutes(30),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

internal static class JwtRegisteredClaimNames
{
    internal const string Subject = "sub";
}
