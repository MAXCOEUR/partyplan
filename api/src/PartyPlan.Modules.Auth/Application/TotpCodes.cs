namespace PartyPlan.Modules.Auth.Application;

using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Implémentation du contrat de double authentification.
/// <para>
/// Enveloppe mince autour de <see cref="Totp"/> : la logique reste statique et testable
/// contre les vecteurs de la RFC, l'interface n'existe que pour franchir la frontière
/// de module.
/// </para>
/// </summary>
public sealed class TotpCodes : ITotpCodes
{
    public byte[] GenerateSecret() => Totp.GenerateSecret();

    public string ToBase32(byte[] secret) => Base32.Encode(secret);

    public bool Verify(byte[] secret, string? code, DateTimeOffset instant) =>
        Totp.Verify(secret, code, instant);

    public string BuildUri(string issuer, string account, byte[] secret) =>
        Totp.BuildUri(issuer, account, secret);
}
