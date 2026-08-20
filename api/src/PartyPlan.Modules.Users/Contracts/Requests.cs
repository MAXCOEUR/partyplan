namespace PartyPlan.Modules.Users.Contracts;

using System.ComponentModel.DataAnnotations;

/// <summary>Corps des requêtes d'authentification et de compte.</summary>
public sealed record RegisterRequest(
    [Required][EmailAddress][MaxLength(320)] string Email,
    [Required] string Password,
    [Required][MaxLength(120)] string DisplayName);

public sealed record LoginRequest(
    [Required][EmailAddress][MaxLength(320)] string Email,
    [Required] string Password);

public sealed record RefreshRequest([Required] string RefreshToken);

/// <summary>
/// Rattachement d'une participation d'invité au compte connecté (EF-AUTH-11).
/// <para>
/// Endpoint distinct plutôt que champ ajouté à l'inscription et à la connexion :
/// l'API compte quatre points d'ouverture de session — inscription, connexion, second
/// facteur, connexion tierce. Un champ n'en couvrirait que deux, et tout compte protégé
/// par un second facteur perdrait silencieusement sa participation.
/// </para>
/// </summary>
public sealed record ClaimGuestRequest([Required] string GuestToken);

/// <summary>Nombre de participations rattachées. Zéro n'est pas une erreur.</summary>
public sealed record ClaimGuestResponse(int Linked);

public sealed record ForgotPasswordRequest(
    [Required][EmailAddress][MaxLength(320)] string Email);

public sealed record ResetPasswordRequest(
    [Required] string Token,
    [Required] string NewPassword);

public sealed record ChangePasswordRequest(
    [Required] string CurrentPassword,
    [Required] string NewPassword);

public sealed record VerifyEmailRequest([Required] string Token);

public sealed record ChangeEmailRequest(
    [Required][EmailAddress][MaxLength(320)] string NewEmail);

public sealed record UpdateProfileRequest(
    [MaxLength(120)] string? DisplayName,
    [MaxLength(10)] string? Locale,
    [MaxLength(64)] string? Timezone);

/// <summary>
/// Suppression de compte. L'adresse est exigée en confirmation : l'opération est
/// irréversible et touche des données financières partagées (RG-USR-05).
/// </summary>
public sealed record DeleteAccountRequest(
    [Required][EmailAddress] string EmailConfirmation);

public sealed record TotpActivateRequest([Required] string Code);

public sealed record TotpDisableRequest([Required] string Password);

/// <summary>Jeton d'identité obtenu auprès du fournisseur par le client.</summary>
public sealed record ExternalSignInRequest([Required] string IdToken);

public sealed record MfaVerifyRequest(
    [Required] string ChallengeToken,
    [Required] string Code);

/// <summary>Jetons remis au client.</summary>
public sealed record TokenResponse(
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt);

/// <summary>
/// Réponse de connexion. Soit les jetons de session, soit un défi de second facteur —
/// jamais les deux.
/// </summary>
public sealed record LoginResponse(
    bool RequiresSecondFactor,
    string? AccessToken,
    DateTimeOffset? AccessTokenExpiresAt,
    string? RefreshToken,
    DateTimeOffset? RefreshTokenExpiresAt,
    string? ChallengeToken,
    DateTimeOffset? ChallengeExpiresAt);
