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
    IDiffusionEvenement diffusion,
    IClock clock,
    IIdGenerator ids) : IJournalActivite
{
    /// <summary>
    /// Sérialisation sans échappement agressif. Les libellés sont français, et
    /// « Glaçons » stocké en <c>Glaçons</c> serait illisible en base — or c'est en
    /// base qu'on relit ce fil le jour d'un désaccord.
    /// </summary>
    private static readonly JsonSerializerOptions Options = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    /// <summary>
    /// Lignes consignées, en attente de validation puis de diffusion. La portée est
    /// celle de la requête : ce tampon ne franchit jamais deux appelants.
    /// </summary>
    private readonly List<ActivityEntry> _enAttente = [];

    public void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null)
    {
        var entree = new ActivityEntry
        {
            Id = ids.NewId(),
            EventId = eventId,
            MemberId = memberId,
            ActorName = actorName,
            Kind = kind,
            Payload = donnees is null ? null : JsonSerializer.Serialize(donnees, Options),
            CreatedAt = clock.UtcNow,
        };

        db.ActivityEntries.Add(entree);
        _enAttente.Add(entree);

        // Aucun SaveChangesAsync ici, et c'est tout l'intérêt : l'entrée est validée par
        // l'appelant, donc dans la même transaction que l'action métier.
    }

    public async Task PublierEnAttenteAsync(CancellationToken cancellationToken)
    {
        if (_enAttente.Count == 0)
        {
            return;
        }

        // Vidée d'abord : un échec de diffusion ne doit pas laisser des lignes qui
        // repartiraient en double au prochain appel de la même requête.
        var aPublier = _enAttente.ToArray();
        _enAttente.Clear();

        foreach (var entree in aPublier)
        {
            await diffusion
                .PublierAsync(
                    entree.EventId,
                    MessagesTempsReel.ActiviteAjoutee,
                    new
                    {
                        id = entree.Id,
                        memberId = entree.MemberId,
                        actorName = entree.ActorName,
                        kind = entree.Kind,
                        // Réinjecté en objet et non en chaîne : le client lirait sinon
                        // du JSON encodé dans du JSON.
                        donnees = entree.Payload is null
                            ? (JsonElement?)null
                            : JsonDocument.Parse(entree.Payload).RootElement,
                        createdAt = entree.CreatedAt,
                        // Pas d'avatarUrl : l'application connaît déjà les membres de
                        // l'événement, et l'inclure obligerait à lire la liste à chaque
                        // ligne consignée.
                    },
                    cancellationToken)
                .ConfigureAwait(false);
        }
    }
}
