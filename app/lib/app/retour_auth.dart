import 'router.dart';

/// Destination conservée pendant une authentification.
///
/// Une valeur `retour` est contrôlée comme une route interne d'invitation avant
/// d'être employée. Cela évite qu'une URL fournie par un lien public devienne une
/// redirection ouverte après la connexion ou l'inscription.
abstract final class RetourAuth {
  /// Retourne une route d'aperçu d'invitation sûre, ou l'accueil.
  static String destination(String? retour) {
    if (retour == null || retour.isEmpty) {
      return PpRoutes.accueil;
    }

    final uri = Uri.tryParse(retour);
    if (uri == null ||
        uri.scheme.isNotEmpty ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith('/')) {
      return PpRoutes.accueil;
    }

    final segments = uri.pathSegments;
    if (segments.length != 2 ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment.contains('/') ||
              segment.contains('?') ||
              segment.contains('#'),
        )) {
      return PpRoutes.accueil;
    }

    final estInvitation =
        segments.first == 'join' || segments.first == 'rejoindre';
    return estInvitation ? uri.path : PpRoutes.accueil;
  }

  /// Construit l'URL de connexion sans laisser la destination modifier sa structure.
  static String versConnexion(String destination) => Uri(
    path: PpRoutes.connexion,
    queryParameters: {'retour': destination},
  ).toString();

  /// Construit l'URL d'inscription sans laisser la destination modifier sa structure.
  static String versInscription(String destination) => Uri(
    path: PpRoutes.inscription,
    queryParameters: {'retour': destination},
  ).toString();
}
