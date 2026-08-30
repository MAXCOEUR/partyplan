namespace PartyPlan.Modules.Notifications.Application;

/// <summary>
/// Règle de résolution d'une préférence par catégorie, hors sourdine : écart de la
/// soirée, puis préférence globale, puis valeur d'usine (autorisé).
/// <para>
/// Extraite ici pour n'exister qu'à un seul endroit. <see cref="EnvoiNotifications"/>
/// l'applique à l'envoi ; <see cref="NotificationService"/> en rend le résultat à la
/// lecture. Deux implémentations de cette même règle, même proches, finissent toujours
/// par diverger — l'une des deux change un jour sans que l'autre suive.
/// </para>
/// <para>
/// La sourdine de la soirée reste volontairement hors de cette résolution : c'est un
/// interrupteur général, que chaque appelant vérifie à part, pas une réponse par
/// catégorie (voir <see cref="NotificationService.PreferencesDeSoireeAsync"/>).
/// </para>
/// </summary>
internal static class ResolutionPreference
{
    /// <summary><c>ecart</c> et <c>globale</c> sont nuls en l'absence de ligne.</summary>
    public static bool EstActivee(bool? ecart, bool? globale) => ecart ?? globale ?? true;
}
