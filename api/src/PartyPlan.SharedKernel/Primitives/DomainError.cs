namespace PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Erreur métier. Le code est stable et destiné au client ; le message est destiné
/// à l'affichage. La correspondance avec un statut HTTP est faite une seule fois,
/// dans le gestionnaire d'erreurs de l'hôte.
/// </summary>
public sealed record DomainError(string Code, string Message, ErrorKind Kind)
{
    public static DomainError NotFound(string code, string message) => new(code, message, ErrorKind.NotFound);

    public static DomainError Unauthenticated(string code, string message) => new(code, message, ErrorKind.Unauthenticated);

    public static DomainError Forbidden(string code, string message) => new(code, message, ErrorKind.Forbidden);

    public static DomainError Conflict(string code, string message) => new(code, message, ErrorKind.Conflict);

    public static DomainError Validation(string code, string message) => new(code, message, ErrorKind.Validation);

    public static DomainError Rule(string code, string message) => new(code, message, ErrorKind.RuleViolation);
}

public enum ErrorKind
{
    /// <summary>Corps de requête invalide — 400.</summary>
    Validation,

    /// <summary>Appelant non authentifié — 401.</summary>
    Unauthenticated,

    /// <summary>Appartenance établie mais droit insuffisant — 403.</summary>
    Forbidden,

    /// <summary>
    /// Ressource inexistante ou hors du périmètre de l'appelant — 404.
    /// Les deux cas partagent le même code afin de ne pas confirmer l'existence
    /// d'une ressource (RG-SEC-02).
    /// </summary>
    NotFound,

    /// <summary>Conflit métier : article déjà attribué, code court en collision — 409.</summary>
    Conflict,

    /// <summary>Règle de gestion violée : montant négatif, assiette vide — 422.</summary>
    RuleViolation,
}
