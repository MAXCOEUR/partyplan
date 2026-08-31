import 'lien_notification.dart';

/// Une notification poussée, telle que l'application la reçoit.
///
/// La charge vient de l'extérieur : chaque champ est validé comme tel, et rien n'y lève.
/// Une notification mal formée se perd — perdre l'avis vaut mieux que casser l'écran
/// qu'on est en train de lire.
class NotificationRecue {
  const NotificationRecue({
    required this.titre,
    required this.corps,
    required this.categorie,
    required this.evenementId,
    required this.destination,
  });

  /// Construit depuis la charge d'un message FCM, ou renvoie `null` s'il n'y a rien à
  /// montrer.
  ///
  /// Le titre et le corps voyagent hors de `data`, dans le bloc `notification` du
  /// message : c'est ce bloc que le système affiche lui-même en arrière-plan, et il
  /// reste la source des deux textes au premier plan.
  static NotificationRecue? depuis(
    Map<String, dynamic>? donnees, {
    required String? titre,
    required String? corps,
  }) {
    final titreNet = titre?.trim() ?? '';
    final corpsNet = corps?.trim() ?? '';

    // Sans texte, un bandeau serait une gêne sans information.
    if (titreNet.isEmpty && corpsNet.isEmpty) {
      return null;
    }

    return NotificationRecue(
      titre: titreNet,
      corps: corpsNet,
      categorie: _texte(donnees?['categorie']),
      evenementId: _texte(donnees?['evenement']),
      // Même validation que celle du tap : une adresse absolue ou une autorité
      // ouvrirait un site tiers depuis l'intérieur de l'application.
      destination: LienNotification.destination(donnees),
    );
  }

  final String titre;

  final String corps;

  /// Constante de `NotificationCategories`, côté serveur. Nulle si le message n'en porte
  /// pas — un message ancien, ou une charge tronquée.
  final String? categorie;

  /// Soirée concernée, nulle pour une notification qui n'en relève pas.
  final String? evenementId;

  /// Route interne ouverte au tap, ou `null` si aucune n'est exploitable.
  final String? destination;

  /// Renvoie la valeur si c'est du texte non vide, sinon `null`.
  ///
  /// FCM ne transporte que des chaînes dans `data`, mais la carte reçue est typée
  /// `dynamic` : un champ d'un autre type est ignoré plutôt que converti de force.
  static String? _texte(Object? valeur) =>
      valeur is String && valeur.isNotEmpty ? valeur : null;
}
