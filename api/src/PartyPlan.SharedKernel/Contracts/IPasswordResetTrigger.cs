namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Déclenchement d'un envoi de lien de réinitialisation. Contrat minimal, implémenté par
/// le module Users : l'administration n'a pas à connaître le mécanisme des jetons.
/// </summary>
public interface IPasswordResetTrigger
{
    Task SendResetLinkAsync(string emailAddress, CancellationToken cancellationToken);
}
