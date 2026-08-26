namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Identité d'un compte, telle que les autres modules ont besoin de la connaître.
/// <para>
/// L'URL de la photo en fait partie : sans elle, chaque module affichant une personne
/// devrait interroger le module Users lui-même, ce que la règle des frontières interdit,
/// ou se résigner à un rond de couleur. C'est ce qui se passait jusqu'au 25/08/2026.
/// </para>
/// </summary>
/// <param name="Id">Identifiant du compte.</param>
/// <param name="DisplayName">Nom affiché.</param>
/// <param name="AvatarUrl">Photo de profil, ou nul.</param>
/// <param name="Timezone">
/// Fuseau horaire déclaré du compte (EF-USR-07), <c>Europe/Paris</c> par défaut. Porté
/// ici parce que RG-NOT-01 interdit d'envoyer entre 22 h et 8 h « heure locale du
/// destinataire » : sans le fuseau, la règle est inapplicable.
/// </param>
public sealed record UserIdentity(
    Guid Id,
    string DisplayName,
    string? AvatarUrl,
    string Timezone = "Europe/Paris");

public interface IUserIdentityLookup
{
    Task<UserIdentity?> FindAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// Identités de plusieurs comptes, en une requête.
    /// <para>
    /// Nécessaire pour lister les membres d'un événement : un appel par membre ferait
    /// vingt requêtes pour vingt personnes, et le coût suivrait la taille de la soirée.
    /// Les identifiants inconnus sont simplement absents du résultat.
    /// </para>
    /// </summary>
    Task<IReadOnlyDictionary<Guid, UserIdentity>> FindManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
