namespace PartyPlan.Modules.Tasks.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Tâche de préparation (EF-TSK-01). Nommée <c>EventTask</c> et non <c>Task</c> pour
/// ne pas entrer en conflit avec <see cref="System.Threading.Tasks.Task"/>.
/// </summary>
public sealed class EventTask : IEventScoped, IAuditable, ISoftDeletable
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public string Label { get; set; } = string.Empty;

    public Guid? AssignedMemberId { get; set; }

    public DateTimeOffset? DueAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public Guid? CompletedByMemberId { get; set; }

    public int Position { get; set; }

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public bool IsDone => CompletedAt is not null;
}
