namespace PartyPlan.SharedKernel.Errors;

/// <summary>
/// Levée lorsqu'un module tente d'accéder à des données dont il n'est pas propriétaire.
/// Cette violation est une anomalie de conception, pas un cas métier : elle échoue
/// bruyamment plutôt que de renvoyer une erreur à l'utilisateur (ADR 0002).
/// </summary>
public sealed class ModuleBoundaryException : InvalidOperationException
{
    public ModuleBoundaryException(string module, string entity)
        : base($"Le module « {module} » n'a pas accès à l'entité « {entity} ». " +
               "Passer par l'interface publique du module propriétaire (ADR 0002).")
    {
    }

    public ModuleBoundaryException(string message) : base(message)
    {
    }

    public ModuleBoundaryException(string message, Exception innerException) : base(message, innerException)
    {
    }

    public ModuleBoundaryException()
    {
    }
}
