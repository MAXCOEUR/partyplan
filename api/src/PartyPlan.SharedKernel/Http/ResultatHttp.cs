namespace PartyPlan.SharedKernel.Http;

using Microsoft.AspNetCore.Http;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Traduction d'un <see cref="Result"/> en réponse HTTP, au format RFC 9457 (§8.1).
/// <para>
/// Écrit une seule fois ici plutôt que recopié dans chaque module : la correspondance
/// entre une nature d'erreur métier et un statut HTTP est une décision de contrat, et
/// deux modules qui en divergeraient rendraient l'API imprévisible pour ses clients.
/// </para>
/// </summary>
public static class ResultatHttp
{
    public static IResult Repondre<T>(Result<T> resultat) =>
        resultat.IsSuccess ? Results.Ok(resultat.Value) : Probleme(resultat.Error!);

    public static IResult Repondre(Result resultat) =>
        resultat.IsSuccess ? Results.NoContent() : Probleme(resultat.Error!);

    /// <summary>
    /// Une ressource inexistante et une ressource hors périmètre partagent le statut 404
    /// (RG-SEC-02) : répondre « accès refusé » révélerait que la ressource existe.
    /// </summary>
    public static IResult Probleme(DomainError erreur)
    {
        ArgumentNullException.ThrowIfNull(erreur);

        return Results.Problem(
            title: erreur.Message,
            statusCode: erreur.Kind switch
            {
                ErrorKind.Validation => StatusCodes.Status400BadRequest,
                ErrorKind.Unauthenticated => StatusCodes.Status401Unauthorized,
                ErrorKind.Forbidden => StatusCodes.Status403Forbidden,
                ErrorKind.NotFound => StatusCodes.Status404NotFound,
                ErrorKind.Conflict => StatusCodes.Status409Conflict,
                ErrorKind.RuleViolation => StatusCodes.Status422UnprocessableEntity,
                _ => StatusCodes.Status500InternalServerError,
            },
            extensions: new Dictionary<string, object?> { ["code"] = erreur.Code });
    }
}
