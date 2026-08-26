namespace PartyPlan.Modules.Events.Application;

using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Une ligne du fil, telle que l'application la reçoit.
/// <para>
/// <paramref name="Donnees"/> porte des données brutes et jamais une phrase : la ligne
/// est inaltérable en base (RG-FIL-02), et une formulation stockée le serait aussi. La
/// phrase est composée par l'application, ce qui la laisse corrigible et traduisible
/// (NF-I18N-01).
/// </para>
/// </summary>
public sealed record ActivityView(
    Guid Id,
    Guid? MemberId,
    string ActorName,
    string? AvatarUrl,
    string Kind,
    JsonElement? Donnees,
    DateTimeOffset CreatedAt);

/// <summary>
/// Une page du fil, du plus récent au plus ancien.
/// <para>
/// <paramref name="HasMore"/> dit s'il reste des lignes plus anciennes à demander. Sans
/// lui, l'application redemanderait indéfiniment une page qui n'existe pas.
/// </para>
/// </summary>
public sealed record ActivityPage(IReadOnlyList<ActivityView> Items, bool HasMore);

/// <summary>
/// Lecture du fil d'activité (EF-FIL-01).
/// <para>
/// Aucune écriture ici : le fil est alimenté par <see cref="IJournalActivite"/>, depuis
/// les modules qui agissent. Ce service ne sait que relire.
/// </para>
/// </summary>
public sealed class ActivityService(
    IEventsDbContext db,
    IEventMembership membership)
{
    /// <summary>Nombre de lignes rendues à défaut de demande explicite.</summary>
    public const int LimiteParDefaut = 30;

    /// <summary>Plafond de lecture, vérifié avant toute requête.</summary>
    public const int LimiteMaximale = 100;

    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError LimiteInvalide = DomainError.Validation(
        "activity.limit_invalid",
        $"La limite doit être comprise entre 1 et {LimiteMaximale}.");

    public async Task<Result<ActivityPage>> ListerAsync(
        Guid eventId,
        Guid? avant,
        int limite,
        CancellationToken cancellationToken)
    {
        // Contrôlée avant toute lecture : accepter une valeur absurde puis la rejeter
        // ferait payer la requête.
        if (limite is < 1 or > LimiteMaximale)
        {
            return LimiteInvalide;
        }

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var requete = db.ActivityEntries.Where(a => a.EventId == eventId);

        if (avant is { } curseur)
        {
            // Le curseur porte sur l'horodatage, l'identifiant ne départageant que les
            // ex æquo. Une même action consigne parfois plusieurs lignes dans la même
            // milliseconde : trier sur le seul horodatage rendrait l'ordre instable, et
            // la pagination sauterait ou répéterait des lignes.
            var repere = await db.ActivityEntries
                .Where(a => a.Id == curseur)
                .Select(a => new { a.CreatedAt, a.Id })
                .FirstOrDefaultAsync(cancellationToken)
                .ConfigureAwait(false);

            if (repere is not null)
            {
                requete = requete.Where(a =>
                    a.CreatedAt < repere.CreatedAt
                    || (a.CreatedAt == repere.CreatedAt
                        && a.Id.CompareTo(repere.Id) < 0));
            }
        }

        // Une ligne de plus que demandé : sa présence répond HasMore sans compter la
        // table entière à chaque page.
        var lignes = await requete
            .OrderByDescending(a => a.CreatedAt)
            .ThenByDescending(a => a.Id)
            .Take(limite + 1)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var encore = lignes.Count > limite;
        if (encore)
        {
            lignes.RemoveAt(lignes.Count - 1);
        }

        var avatars = (await membership.ListActiveAsync(eventId, cancellationToken)
                .ConfigureAwait(false))
            .ToDictionary(m => m.MemberId, m => m.AvatarUrl);

        var vues = lignes.ConvertAll(a => new ActivityView(
            a.Id,
            a.MemberId,
            // Le nom reste celui figé à l'écriture (RG-USR-04) : un changement de nom
            // ne réécrit pas l'histoire. La photo, elle, est celle d'aujourd'hui —
            // c'est ainsi qu'on reconnaît la personne dans la liste.
            a.ActorName,
            a.MemberId is { } id && avatars.TryGetValue(id, out var avatar) ? avatar : null,
            a.Kind,
            a.Payload is null ? null : JsonDocument.Parse(a.Payload).RootElement,
            a.CreatedAt));

        return new ActivityPage(vues, encore);
    }
}
