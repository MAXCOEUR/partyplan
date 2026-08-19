/// Validation côté interface.
///
/// Elle double la validation du serveur, elle ne la remplace pas : le serveur reste
/// la seule autorité (`RG-AUTH-01`). L'intérêt ici est d'éviter un aller-retour réseau
/// pour une faute évidente.
abstract final class Validateurs {
  /// Longueur minimale, alignée sur `RG-AUTH-01`.
  static const longueurMotDePasse = 12;

  static String? adresse(String? valeur) {
    final texte = valeur?.trim() ?? '';

    if (texte.isEmpty) {
      return 'Indique ton adresse e-mail.';
    }

    // Volontairement permissif : la validation exacte d'une adresse est notoirement
    // impossible par expression régulière, et la vérification par courriel tranche.
    if (!texte.contains('@') || !texte.contains('.') || texte.length < 5) {
      return 'Cette adresse ne ressemble pas à une adresse e-mail.';
    }

    return null;
  }

  static String? motDePasse(String? valeur) {
    final texte = valeur ?? '';

    if (texte.isEmpty) {
      return 'Indique un mot de passe.';
    }

    if (texte.length < longueurMotDePasse) {
      return 'Il manque ${longueurMotDePasse - texte.length} caractère(s) : '
          '$longueurMotDePasse au minimum.';
    }

    return null;
  }

  static String? motDePasseExistant(String? valeur) =>
      (valeur ?? '').isEmpty ? 'Indique ton mot de passe.' : null;

  static String? prenom(String? valeur) =>
      (valeur?.trim() ?? '').isEmpty ? 'Indique ton prénom.' : null;

  static String? code(String? valeur) => (valeur?.trim() ?? '').isEmpty
      ? 'Colle le code reçu par courriel.'
      : null;
}
