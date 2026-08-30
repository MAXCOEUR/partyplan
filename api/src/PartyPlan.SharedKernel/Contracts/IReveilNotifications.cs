namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Réveille la passe d'envoi sans attendre le tour d'horloge.
/// <para>
/// Appelé <b>après</b> la validation de la transaction métier, jamais pendant : une
/// notification inscrite mais non validée ne doit pas partir. Le réveil est un signal
/// en mémoire, ce que l'instance unique déjà imposée par l'ordonnanceur autorise
/// (<c>docs/exploitation.md</c> §1.2).
/// </para>
/// <para>
/// Ne réveille que l'envoi. La planification reste à la cadence : la relancer à chaque
/// message recalculerait les rappels de toutes les soirées.
/// </para>
/// </summary>
public interface IReveilNotifications
{
    void Reveiller();
}
