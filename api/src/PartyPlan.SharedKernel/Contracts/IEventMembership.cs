namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Membre d'un événement, tel que les autres modules ont besoin de le connaître.
/// <para>
/// Volontairement réduit : ni statut détaillé, ni horaires, ni accompagnants. Un module
/// financier n'a besoin que de savoir qui existe, qui compte comme présent — pour
/// l'assiette « tous les présents » — et qui peut gérer.
/// </para>
/// </summary>
public sealed record EventMemberRef(
    Guid MemberId,
    string DisplayName,
    string? AvatarUrl,
    bool CountsAsPresent,
    bool CanManage);

/// <summary>
/// Appartenance à un événement. Contrat public du module Events, consommé par Shopping,
/// Expenses et Settlements, qui n'accèdent jamais à <c>event_members</c>.
/// </summary>
public interface IEventMembership
{
    /// <summary>Membres actifs, dans l'ordre d'adhésion. Les exclus sont omis.</summary>
    Task<IReadOnlyList<EventMemberRef>> ListActiveAsync(
        Guid eventId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Membre correspondant au compte appelant. Les lignes historiques sans compte
    /// restent listables mais ne peuvent pas représenter l'appelant. <c>null</c> lorsque
    /// le compte n'est pas membre — auquel cas l'appelant répond 404, jamais « accès
    /// refusé » (RG-SEC-02).
    /// </summary>
    Task<EventMemberRef?> FindCurrentAsync(Guid eventId, CancellationToken cancellationToken);

    /// <summary>
    /// Appartenance d'un compte désigné explicitement, hors de toute requête HTTP.
    /// <para>
    /// Nécessaire au hub temps réel, et à lui seul. Les autres méthodes lisent l'appelant
    /// dans le contexte HTTP et s'appuient sur le périmètre d'événements amorcé par
    /// l'intergiciel — deux choses qui n'existent pas dans un <c>OnConnectedAsync</c> de
    /// SignalR, qui s'exécute dans son propre périmètre d'injection et sans contexte de
    /// requête. Les utiliser depuis le hub renvoyait « non membre » pour tout le monde :
    /// personne ne rejoignait son groupe, et aucun changement n'était jamais reçu.
    /// </para>
    /// </summary>
    Task<bool> IsMemberAsync(Guid eventId, Guid userId, CancellationToken cancellationToken);
}
