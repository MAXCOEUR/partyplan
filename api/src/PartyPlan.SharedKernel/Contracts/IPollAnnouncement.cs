namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Annonce d'un sondage dans la discussion de l'événement.
/// <para>
/// Contrat public du module Messages, consommé par Polls. C'est dans la conversation
/// qu'on se demande quoi faire : un sondage créé sans y paraître passerait inaperçu.
/// Le module Polls n'accède jamais à la table des messages (ADR 0002).
/// </para>
/// </summary>
public interface IPollAnnouncement
{
    /// <summary>
    /// Publie un message portant le sondage, au nom du membre qui l'a créé. Renvoie
    /// l'identifiant du message publié.
    /// </summary>
    Task<Guid> AnnounceAsync(
        Guid eventId,
        Guid memberId,
        Guid pollId,
        string question,
        CancellationToken cancellationToken);
}
