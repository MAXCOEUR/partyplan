namespace PartyPlan.Infrastructure.Identity;

using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Enums;

/// <summary>Types de revendications propres à PartyPlan.</summary>
public static class PartyPlanClaims
{
    public const string PlatformRole = "pp:platform_role";

    public const string SessionId = "pp:session";

    /// <summary>Mot de passe à changer avant toute autre action (RG-ADM-10).</summary>
    public const string MustChangePassword = "pp:must_change_password";
}

/// <summary>Appelant courant, lu depuis les revendications de la requête.</summary>
public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;

    public Guid? UserId =>
        Guid.TryParse(Principal?.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    public PlatformRole PlatformRole =>
        Enum.TryParse<PlatformRole>(Principal?.FindFirstValue(PartyPlanClaims.PlatformRole), out var role)
            ? role
            : PlatformRole.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public override string ToString() =>
        string.Create(CultureInfo.InvariantCulture, $"user={UserId}, role={PlatformRole}");
}
