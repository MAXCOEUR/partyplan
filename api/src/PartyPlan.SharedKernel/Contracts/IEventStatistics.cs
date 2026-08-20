namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Décomptes globaux d'événements. Contrat public du module Events.
/// <para>
/// Volontairement limité à des <b>nombres</b>. Savoir qu'une instance héberge quatre-vingts
/// événements actifs ne révèle rien de leur contenu : c'est ce qui rend ce contrat
/// compatible avec RG-ADM-01, qui interdit à un rôle plateforme d'accéder au contenu d'un
/// événement.
/// </para>
/// </summary>
public interface IEventStatistics
{
    Task<EventCounts> CountAsync(CancellationToken cancellationToken);
}

/// <summary>Décomptes d'instance. Aucun identifiant, aucun nom, aucune donnée nominative.</summary>
public sealed record EventCounts(int Total, int Active, int GuestMembers);
