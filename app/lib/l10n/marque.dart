/// Éléments de marque, non traduisibles.
///
/// Séparés des chaînes d'interface : un nom de produit ne se traduit pas, et le placer
/// dans un fichier ARB inviterait un traducteur à le faire.
abstract final class PpMarque {
  static const nom = 'PartyPlan';

  /// Signature de la marque, fixée par `docs/brand/charte.md`.
  ///
  /// Affichée sous les écrans de compte. Ce sont les trois temps du produit dans
  /// l'ordre où on les vit : on organise, on partage, puis on profite.
  static const signature = 'Organise. Partage. Profite !';
}
