/// Validation côté interface.
///
/// Elle double la validation du serveur, elle ne la remplace pas : le serveur reste
/// la seule autorité (`RG-AUTH-01`). L'intérêt ici est d'éviter un aller-retour réseau
/// pour une faute évidente.
abstract final class Validateurs {
  /// Bornes de longueur, alignées sur `RG-AUTH-01`.
  static const longueurMotDePasse = 8;
  static const longueurMaximaleMotDePasse = 30;

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

    if (texte.length > longueurMaximaleMotDePasse) {
      return '$longueurMaximaleMotDePasse caractères au maximum.';
    }

    // Le message nomme ce qui manque, et une seule chose à la fois. « Mot de passe
    // invalide » obligerait à deviner laquelle des quatre exigences n'est pas remplie,
    // et les énumérer toutes revient à ne rien désigner.
    final manquant = _classeManquante(texte);

    return manquant == null ? null : 'Il faut aussi $manquant.';
  }

  /// Première classe de caractères absente, ou `null` si les quatre sont présentes.
  ///
  /// L'ordre est celui d'un clavier : on ajoute une majuscule avant de chercher un
  /// caractère spécial.
  static String? _classeManquante(String texte) {
    if (!texte.contains(RegExp('[A-ZÀ-Þ]'))) {
      return 'une majuscule';
    }

    if (!texte.contains(RegExp('[a-zß-ÿ]'))) {
      return 'une minuscule';
    }

    if (!texte.contains(RegExp('[0-9]'))) {
      return 'un chiffre';
    }

    // Par exclusion et non par liste fermée, comme le serveur : une liste refuserait
    // un caractère légitime imprévu.
    if (!texte.contains(RegExp('[^0-9A-Za-zÀ-ÿ]'))) {
      return 'un caractère spécial';
    }

    return null;
  }

  /// Seconde saisie du mot de passe.
  ///
  /// Une faute de frappe sur un mot de passe masqué ne se voit pas : sans confirmation,
  /// la personne se retrouve enfermée dehors avec un mot de passe qu'elle croit
  /// connaître. C'est le seul endroit où une double saisie se justifie.
  static String? confirmation(String? mdp, String? valeur) {
    final texte = valeur ?? '';

    if (texte.isEmpty) {
      return 'Saisis une seconde fois le mot de passe.';
    }

    return texte == (mdp ?? '')
        ? null
        : 'Les deux saisies ne correspondent pas.';
  }

  static String? motDePasseExistant(String? valeur) =>
      (valeur ?? '').isEmpty ? 'Indique ton mot de passe.' : null;

  static String? prenom(String? valeur) =>
      (valeur?.trim() ?? '').isEmpty ? 'Indique ton prénom.' : null;

  static String? code(String? valeur) => (valeur?.trim() ?? '').isEmpty
      ? 'Colle le code reçu par courriel.'
      : null;
}
