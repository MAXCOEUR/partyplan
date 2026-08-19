namespace PartyPlan.Modules.Polls.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Sondage (EF-SDG-01). Choix unique au MVP ; le choix multiple est reporté (EF-SDG-05).</summary>
public sealed class Poll : IEventScoped, IAuditable, ISoftDeletable
{
    public const int MinOptions = 2;
    public const int MaxOptions = 10;

    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public string Question { get; set; } = string.Empty;

    public bool AllowMultiple { get; set; }

    public bool IsAnonymous { get; set; }

    public DateTimeOffset? ClosesAt { get; set; }

    public DateTimeOffset? ClosedAt { get; set; }

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public ICollection<PollOption> Options { get; } = new List<PollOption>();

    public bool IsOpen(DateTimeOffset now) =>
        ClosedAt is null && (ClosesAt is null || ClosesAt > now);
}

public sealed class PollOption
{
    public Guid Id { get; set; }

    public Guid PollId { get; set; }

    public string Label { get; set; } = string.Empty;

    public int Position { get; set; }

    public ICollection<PollVote> Votes { get; } = new List<PollVote>();
}

/// <summary>Vote. Modifiable tant que le sondage est ouvert (EF-SDG-02).</summary>
public sealed class PollVote
{
    public Guid Id { get; set; }

    public Guid PollId { get; set; }

    public Guid OptionId { get; set; }

    public Guid MemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}
