namespace PartyPlan.Modules.Expenses.Domain;

/// <summary>Part attribuée à un membre, en centimes.</summary>
public readonly record struct PartAttribuee(Guid MemberId, int Cents);

/// <summary>
/// Répartition d'une dépense au centime, par la règle des plus grands restes (§6.2).
/// <para>
/// Fonction pure, sans dépendance ni état : c'est la règle la plus sensible du produit,
/// et elle doit pouvoir être éprouvée sans base, sans réseau et sans horloge. Une erreur
/// d'un centime ici se propage à tous les soldes et à tous les règlements.
/// </para>
/// <para>
/// Le calcul se fait en centimes entiers, jamais en décimal ni en flottant : additionner
/// des arrondis successifs ferait dériver la somme, et l'invariant IV-01 exige l'égalité
/// exacte.
/// </para>
/// </summary>
public static class Repartition
{
    /// <summary>
    /// Répartit <paramref name="montantCents"/> entre les participants au prorata de
    /// leurs parts.
    /// </summary>
    /// <returns>
    /// Les parts attribuées, dans l'ordre croissant d'identifiant de membre. La somme
    /// des parts égale exactement le montant (invariant IV-01).
    /// </returns>
    public static IReadOnlyList<PartAttribuee> Repartir(
        int montantCents,
        IReadOnlyCollection<(Guid MemberId, int Share)> assiette)
    {
        ArgumentNullException.ThrowIfNull(assiette);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(montantCents);

        if (assiette.Count == 0)
        {
            throw new ArgumentException(
                "Une dépense a au moins un participant.",
                nameof(assiette));
        }

        foreach (var (_, share) in assiette)
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(share, nameof(assiette));
        }

        // Tri par identifiant dès l'entrée : le résultat ne doit pas dépendre de l'ordre
        // dans lequel l'appelant fournit l'assiette (RG-RMB-01).
        var participants = assiette.OrderBy(p => p.MemberId).ToList();
        var total = participants.Sum(p => (long)p.Share);

        // Part théorique en centimes, et son reste fractionnaire exprimé en numérateur
        // sur le dénominateur commun `total`. Comparer des numérateurs entiers plutôt que
        // des fractions décimales évite toute question d'égalité approchée.
        var lignes = participants
            .Select(p =>
            {
                var numerateur = (long)montantCents * p.Share;

                return new
                {
                    p.MemberId,
                    Plancher = (int)(numerateur / total),
                    Reste = numerateur % total,
                };
            })
            .ToList();

        var reliquat = montantCents - lignes.Sum(l => (long)l.Plancher);

        // Les `reliquat` centimes restants vont aux plus grands restes. À reste égal,
        // l'identifiant croissant tranche : sans cet ordre explicite, deux exécutions
        // identiques pourraient produire deux répartitions différentes, et les tests
        // automatisés seraient impossibles à écrire.
        var beneficiaires = lignes
            .OrderByDescending(l => l.Reste)
            .ThenBy(l => l.MemberId)
            .Take((int)reliquat)
            .Select(l => l.MemberId)
            .ToHashSet();

        return
        [
            .. lignes.Select(l => new PartAttribuee(
                l.MemberId,
                l.Plancher + (beneficiaires.Contains(l.MemberId) ? 1 : 0))),
        ];
    }
}
