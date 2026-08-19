namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Hachage et vérification des mots de passe. Contrat public du module Auth.
/// <para>
/// Exposé sous forme d'interface plutôt que de méthodes statiques : les tests du module
/// Users doivent pouvoir substituer une implémentation rapide, le coût d'Argon2id étant
/// délibérément élevé.
/// </para>
/// </summary>
public interface IPasswordHasher
{
    string Hash(string password);

    bool Verify(string password, string? stored);

    /// <summary>Vrai lorsque l'empreinte utilise des paramètres plus faibles que les paramètres courants.</summary>
    bool NeedsRehash(string? stored);
}

/// <summary>Politique de mot de passe (RG-AUTH-01). Contrat public du module Auth.</summary>
public interface IPasswordPolicy
{
    Result Validate(string? password);
}
