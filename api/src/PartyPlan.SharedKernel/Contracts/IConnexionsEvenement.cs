namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Retrait d'un compte du canal temps réel d'un événement. Implémenté par
/// l'Infrastructure, consommé par le module Events.
/// <para>
/// Nécessaire parce que l'appartenance est vérifiée <b>à l'établissement de la
/// connexion</b> et non à chaque message (RG-RT-01). C'est le bon arbitrage — une
/// vérification par message coûterait une requête à chaque diffusion — mais il a une
/// contrepartie : sans ce retrait, un membre exclu garde son abonnement et continue de
/// recevoir les montants et la discussion d'une soirée dont il n'est plus membre,
/// jusqu'à ce qu'il relance l'application. Le REST lui est déjà fermé ; le canal temps
/// réel ne doit pas rester ouvert.
/// </para>
/// <para>
/// Ne lève jamais, comme <see cref="IDiffusionEvenement"/> : un retrait manqué ne doit
/// pas faire échouer l'exclusion elle-même. Le membre reste exclu en base, et sa
/// prochaine connexion sera refusée de toute façon.
/// </para>
/// </summary>
public interface IConnexionsEvenement
{
    Task FermerAsync(Guid eventId, Guid userId, CancellationToken cancellationToken);
}
