namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Diffusion d'un changement aux membres connectés d'un événement (§9).
/// <para>
/// Contrat du noyau partagé et non d'un module : six modules diffusent, et aucun ne doit
/// connaître SignalR ni le hub. Même motif que <see cref="IPushSender"/> et
/// <see cref="IAuditLog"/>.
/// </para>
/// <para>
/// Aucune méthode ne lève : une diffusion perdue ne doit jamais faire échouer l'action
/// métier qui l'a déclenchée. Le temps réel est une optimisation (RG-RT-03), et le client
/// retrouve la vérité par une relecture REST.
/// </para>
/// </summary>
public interface IDiffusionEvenement
{
    /// <param name="eventId">Événement dont le groupe reçoit le message.</param>
    /// <param name="message">Un nom de <see cref="MessagesTempsReel"/>.</param>
    /// <param name="charge">
    /// État résultant de la ressource, pas son seul identifiant (RG-RT-02). En pratique
    /// le DTO que l'endpoint REST renvoie déjà.
    /// </param>
    /// <param name="cancellationToken">Jeton d'annulation de la requête en cours.</param>
    Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken);
}

/// <summary>
/// Noms des messages diffusés (§9). Chaînes stables : un client déployé les compare
/// littéralement, en renommer une casse les applications déjà installées.
/// </summary>
public static class MessagesTempsReel
{
    public const string MembreArrive = "member.joined";
    public const string MembreStatutChange = "member.statusChanged";
    public const string MembreRetire = "member.removed";

    public const string ArticleCree = "item.created";
    public const string ArticleModifie = "item.updated";
    public const string ArticleAttribue = "item.claimed";
    public const string ArticleLibere = "item.unclaimed";
    public const string ArticleAchete = "item.purchased";
    public const string ArticleSupprime = "item.deleted";

    public const string DepenseCreee = "expense.created";
    public const string DepenseModifiee = "expense.updated";
    public const string DepenseSupprimee = "expense.deleted";

    public const string SoldesChanges = "balances.changed";
    public const string ReglementMarque = "settlement.marked";
    public const string ReglementAnnule = "settlement.cancelled";

    public const string EvenementModifie = "event.updated";
    public const string ActiviteAjoutee = "activity.appended";

    public const string MessageCree = "message.created";
    public const string MessageModifie = "message.updated";
    public const string MessageSupprime = "message.deleted";
    public const string SondageCree = "poll.created";
    public const string SondageVote = "poll.voted";
}
