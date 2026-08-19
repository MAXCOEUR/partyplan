namespace PartyPlan.UnitTests;

using PartyPlan.Infrastructure.Persistence;
using Shouldly;
using Xunit;

public sealed class EventScopeTests
{
    [Fact]
    public void Un_perimetre_non_initialise_est_vide()
    {
        var scope = new EventScope();

        scope.IsPrimed.ShouldBeFalse();
        scope.AllowedEventIds.ShouldBeEmpty();
    }

    [Fact]
    public void Le_perimetre_dedoublonne_les_identifiants()
    {
        var scope = new EventScope();
        var id = Guid.CreateVersion7();

        scope.Prime([id, id, Guid.CreateVersion7()]);

        scope.AllowedEventIds.Length.ShouldBe(2);
        scope.IsPrimed.ShouldBeTrue();
    }

    [Fact]
    public void Une_autorisation_temporaire_est_retiree_a_la_liberation()
    {
        var scope = new EventScope();
        scope.Prime([]);
        var eventId = Guid.CreateVersion7();

        using (scope.AllowTemporarily(eventId))
        {
            scope.AllowedEventIds.ShouldContain(eventId);
        }

        // Sans ce retrait, une adhésion élargirait le périmètre pour tout le reste
        // de la requête (EF-INV-04).
        scope.AllowedEventIds.ShouldNotContain(eventId);
    }

    [Fact]
    public void Une_double_liberation_est_sans_effet()
    {
        var scope = new EventScope();
        scope.Prime([]);
        var eventId = Guid.CreateVersion7();

        var lease = scope.AllowTemporarily(eventId);
        lease.Dispose();
        lease.Dispose();

        scope.AllowedEventIds.ShouldBeEmpty();
    }
}
