namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Chiffrement des secrets stockés en base. Implémenté par l'Infrastructure.
/// <para>
/// Un secret TOTP n'est pas un mot de passe : il doit être relu en clair pour vérifier
/// un code, donc être chiffré et non haché. Le stocker tel quel rendrait une fuite de
/// base équivalente à la perte du second facteur de tous les comptes.
/// </para>
/// </summary>
public interface ISecretProtector
{
    string Protect(ReadOnlySpan<byte> secret);

    bool TryUnprotect(string? protectedValue, out byte[] secret);
}
