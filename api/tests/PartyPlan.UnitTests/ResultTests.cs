namespace PartyPlan.UnitTests;

using Microsoft.AspNetCore.Http;
using PartyPlan.Api.Setup;
using PartyPlan.SharedKernel.Primitives;
using Shouldly;
using Xunit;

public sealed class ResultTests
{
    [Fact]
    public void Un_resultat_en_echec_ne_donne_pas_de_valeur()
    {
        Result<int> result = DomainError.NotFound("x.not_found", "Introuvable.");

        result.IsFailure.ShouldBeTrue();
        Should.Throw<InvalidOperationException>(() => result.Value);
    }

    [Fact]
    public void Un_resultat_reussi_porte_sa_valeur()
    {
        Result<int> result = 42;

        result.IsSuccess.ShouldBeTrue();
        result.Value.ShouldBe(42);
        result.Error.ShouldBeNull();
    }

    [Theory]
    [InlineData(ErrorKind.Validation, StatusCodes.Status400BadRequest)]
    [InlineData(ErrorKind.Unauthenticated, StatusCodes.Status401Unauthorized)]
    [InlineData(ErrorKind.Forbidden, StatusCodes.Status403Forbidden)]
    [InlineData(ErrorKind.NotFound, StatusCodes.Status404NotFound)]
    [InlineData(ErrorKind.Conflict, StatusCodes.Status409Conflict)]
    [InlineData(ErrorKind.RuleViolation, StatusCodes.Status422UnprocessableEntity)]
    public void La_correspondance_avec_les_statuts_http_suit_le_cahier_des_charges(
        ErrorKind kind, int expected)
    {
        // §8.3 : la table de correspondance est normative.
        ProblemDetailsSetup.ToStatusCode(kind).ShouldBe(expected);
    }
}
