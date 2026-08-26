namespace PartyPlan.Infrastructure.Journal;

using System.Text.Encodings.Web;
using System.Text.Json;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Seule implémentation de <see cref="IJournalActivite"/>. Écrit dans le contexte
/// unique, donc dans l'unité de travail de la requête en cours.
/// </summary>
public sealed class JournalActivite(
    PartyPlanDbContext db,
    IClock clock,
    IIdGenerator ids) : IJournalActivite
{
    /// <summary>
    /// Sérialisation sans échappement agressif. Les libellés sont français, et
    /// « Glaçons » stocké en <c>Glaçons</c> serait illisible en base — or c'est en
    /// base qu'on relit ce fil le jour d'un litige.
    /// </summary>
    private static readonly JsonSerializerOptions Options = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null)
    {
        db.ActivityEntries.Add(new ActivityEntry
        {
            Id = ids.NewId(),
            EventId = eventId,
            MemberId = memberId,
            ActorName = actorName,
            Kind = kind,
            Payload = donnees is null ? null : JsonSerializer.Serialize(donnees, Options),
            CreatedAt = clock.UtcNow,
        });

        // Aucun SaveChangesAsync ici, et c'est tout l'intérêt : l'entrée est validée par
        // l'appelant, donc dans la même transaction que l'action métier.
    }
}
