/// Destination d'une notification.
///
/// Le lien vient de l'extérieur : il est validé comme tel. Le même raisonnement que pour
/// le paramètre « retour » d'une invitation — une adresse absolue, une autorité ou un
/// préfixe « // » ouvrirait un site tiers à l'intérieur de l'application.
abstract final class LienNotification {
  static String? destination(Map<String, dynamic>? donnees) {
    final brut = donnees?['deepLink'];

    if (brut is! String || brut.isEmpty) {
      return null;
    }

    // Une route interne commence par une seule barre. « // » désigne une autorité.
    if (!brut.startsWith('/') || brut.startsWith('//')) {
      return null;
    }

    return brut;
  }
}
