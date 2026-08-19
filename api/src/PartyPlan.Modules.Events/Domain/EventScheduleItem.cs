namespace PartyPlan.Modules.Events.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Étape du planning de l'événement (EF-PLN-01).</summary>
public sealed class EventScheduleItem : IEventScoped, IAuditable
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public DateTimeOffset StartsAt { get; set; }

    public string Label { get; set; } = string.Empty;

    public string? Location { get; set; }

    public string? Note { get; set; }

    /// <summary>Rappel avant l'étape, en minutes (EF-PLN-06). Nul si aucun rappel.</summary>
    public int? ReminderMinutesBefore { get; set; }

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
