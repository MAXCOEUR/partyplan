namespace PartyPlan.Modules.Settlements.Domain;

/// <summary>
/// Ce qu'un membre a avancé et ce qu'il doit, en centimes, agrégé sur les dépenses non
/// supprimées. Fourni par le module Expenses via son contrat public.
/// </summary>
public readonly record struct LigneDeCompte(Guid MemberId, long AvanceCents, long DuCents);

/// <summary>Remboursement déjà effectué et non annulé.</summary>
public readonly record struct ReglementEffectue(Guid FromMemberId, Guid ToMemberId, long Cents);

/// <summary>
/// Solde d'un membre, en centimes. Positif : il doit recevoir. Négatif : il doit payer.
/// </summary>
public readonly record struct Solde(Guid MemberId, long Cents);

/// <summary>Transfert proposé pour éteindre les dettes.</summary>
public readonly record struct Reglement(Guid FromMemberId, Guid ToMemberId, long Cents);

/// <summary>
/// Soldes et simplification des règlements (§6.3 et §6.4).
/// <para>
/// Fonctions pures : aucun solde n'est persisté, tout est recalculé à la demande
/// (RG-RMB-02). Persister un solde créerait une seconde source de vérité à côté des
/// dépenses, et la moindre divergence serait invisible jusqu'au litige.
/// </para>
/// </summary>
public static class Soldes
{
    /// <summary>
    /// Calcule le solde de chaque membre (§6.3).
    /// <para>
    /// <c>solde = avancé − dû + règlements émis − règlements reçus</c>. Un règlement
    /// déjà effectué entre donc dans le calcul suivant (RG-RMB-03) : sans cela, une
    /// dette remboursée réapparaîtrait indéfiniment.
    /// </para>
    /// </summary>
    public static IReadOnlyList<Solde> Calculer(
        IReadOnlyCollection<LigneDeCompte> comptes,
        IReadOnlyCollection<ReglementEffectue> reglements)
    {
        ArgumentNullException.ThrowIfNull(comptes);
        ArgumentNullException.ThrowIfNull(reglements);

        var soldes = comptes.ToDictionary(
            c => c.MemberId,
            c => c.AvanceCents - c.DuCents);

        foreach (var reglement in reglements)
        {
            // Un règlement impliquant un membre inconnu du compte est ignoré plutôt que
            // de faire échouer le calcul : un membre exclu conserve ses lignes
            // financières (RG-ROLE-03), mais peut ne plus figurer dans l'assiette.
            if (soldes.ContainsKey(reglement.FromMemberId))
            {
                soldes[reglement.FromMemberId] += reglement.Cents;
            }

            if (soldes.ContainsKey(reglement.ToMemberId))
            {
                soldes[reglement.ToMemberId] -= reglement.Cents;
            }
        }

        return [.. soldes
            .OrderBy(s => s.Key)
            .Select(s => new Solde(s.Key, s.Value))];
    }

    /// <summary>
    /// Vérifie l'invariant IV-02 : la somme des soldes est nulle.
    /// <para>
    /// Une violation signifie que la répartition et les soldes ont divergé, donc qu'un
    /// utilisateur va lire un montant faux. L'appelant journalise en erreur et
    /// l'interface le signale, plutôt que d'afficher des chiffres qu'on sait mauvais.
    /// </para>
    /// </summary>
    public static bool InvariantRespecte(IReadOnlyCollection<Solde> soldes)
    {
        ArgumentNullException.ThrowIfNull(soldes);

        return soldes.Sum(s => s.Cents) == 0;
    }

    /// <summary>
    /// Simplifie les dettes par appariement glouton (§6.4).
    /// <para>
    /// L'algorithme ne garantit pas le minimum absolu de transactions — le problème est
    /// NP-difficile — mais s'en approche et reste explicable à l'utilisateur, ce qui est
    /// le critère retenu. Le tri explicite des égalités rend le résultat reproductible
    /// (RG-RMB-01).
    /// </para>
    /// </summary>
    /// <returns>
    /// Les transferts, dans l'ordre d'émission. C'est cet ordre que l'interface affiche
    /// (RG-CALC-01) : un tri ultérieur rendrait la liste incompréhensible d'un
    /// rafraîchissement à l'autre.
    /// </returns>
    public static IReadOnlyList<Reglement> Simplifier(IReadOnlyCollection<Solde> soldes)
    {
        ArgumentNullException.ThrowIfNull(soldes);

        var crediteurs = soldes
            .Where(s => s.Cents > 0)
            .OrderByDescending(s => s.Cents)
            .ThenBy(s => s.MemberId)
            .Select(s => (s.MemberId, Reste: s.Cents))
            .ToList();

        var debiteurs = soldes
            .Where(s => s.Cents < 0)
            .OrderBy(s => s.Cents)
            .ThenBy(s => s.MemberId)
            .Select(s => (s.MemberId, Reste: -s.Cents))
            .ToList();

        var reglements = new List<Reglement>();
        var c = 0;
        var d = 0;

        while (c < crediteurs.Count && d < debiteurs.Count)
        {
            var montant = Math.Min(crediteurs[c].Reste, debiteurs[d].Reste);

            // Un transfert de moins d'un centime n'est pas émis (§6.4, point 4).
            if (montant > 0)
            {
                reglements.Add(
                    new Reglement(debiteurs[d].MemberId, crediteurs[c].MemberId, montant));
            }

            crediteurs[c] = (crediteurs[c].MemberId, crediteurs[c].Reste - montant);
            debiteurs[d] = (debiteurs[d].MemberId, debiteurs[d].Reste - montant);

            if (crediteurs[c].Reste == 0)
            {
                c++;
            }

            if (debiteurs[d].Reste == 0)
            {
                d++;
            }
        }

        return reglements;
    }
}
