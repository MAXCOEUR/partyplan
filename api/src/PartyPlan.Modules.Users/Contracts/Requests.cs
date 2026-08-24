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

/// <summary>Jeton d'identité obtenu auprès du fournisseur par le client.</summary>
public sealed record ExternalSignInRequest([Required] string IdToken);

/// <summary>Jetons remis au client.</summary>
public sealed record TokenResponse(
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt);
