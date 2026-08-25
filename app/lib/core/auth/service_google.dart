import 'package:google_sign_in/google_sign_in.dart';

/// Obtention d'un jeton d'identité Google, côté application — `EF-AUTH-06`.
///
/// Une interface plutôt qu'une classe concrète : les écrans se testent sans client
/// Google, qui exige une plateforme réelle et un projet Google Cloud configuré. Le
/// serveur, lui, vérifie déjà la signature du jeton — l'application ne le lit jamais.
abstract interface class ServiceGoogle {
  /// Vrai si l'application embarque un identifiant client utilisable.
  ///
  /// Distinct de « l'instance possède la clé » : les deux sont nécessaires, et les
  /// confondre afficherait un bouton condamné à échouer.
  bool get disponible;

  /// Vrai si la plateforme accepte d'ouvrir le parcours de connexion à la demande.
  ///
  /// Faux sur le Web : `google_sign_in` 7.x y refuse `authenticate()` et impose son
  /// propre bouton rendu par le SDK Google. Sans cette distinction, notre bouton y
  /// serait cliquable et sans effet — le pire des trois états, puisque rien ne le dit.
  bool get parcoursProgrammatique;

  /// Jeton d'identité, ou `null` si la personne a annulé ou si aucun client n'est
  /// embarqué. Une annulation n'est pas une erreur et ne lève pas.
  Future<String?> obtenirJetonIdentite();

  /// Oublie le compte choisi, pour que le sélecteur réapparaisse à la prochaine
  /// connexion. À appeler à la déconnexion, sinon un appareil partagé reconnecterait
  /// le compte précédent d'un seul geste.
  Future<void> oublier();
}

/// Implémentation `google_sign_in`.
///
/// Sans identifiant client, toute opération est sans effet : un clone du dépôt doit
/// rester utilisable et l'inscription par mot de passe suffit (règle 5, NF-DEV-05).
class ServiceGoogleClient implements ServiceGoogle {
  ServiceGoogleClient({String? identifiantClient})
    : _identifiantClient = identifiantClient ?? _depuisLaCompilation;

  /// Injecté à la compilation, comme l'adresse de l'API : `--dart-define`.
  static const _depuisLaCompilation = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  final String _identifiantClient;

  bool _initialise = false;

  @override
  bool get disponible => _identifiantClient.isNotEmpty;

  @override
  bool get parcoursProgrammatique {
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      // Aucune plateforme sous la main : ne rien promettre.
      return false;
    }
  }

  @override
  Future<String?> obtenirJetonIdentite() async {
    if (!disponible) {
      return null;
    }

    try {
      if (!_initialise) {
        await GoogleSignIn.instance.initialize(
          clientId: _identifiantClient,
          serverClientId: _identifiantClient,
        );
        _initialise = true;
      }

      final compte = await GoogleSignIn.instance.authenticate();

      return compte.authentication.idToken;
    } catch (_) {
      // Annulation, absence de service Google Play, configuration incomplète : dans
      // tous les cas la personne se connecte par mot de passe. Capture large car sans
      // plateforme l'appel lève une Error et non une Exception.
      return null;
    }
  }

  @override
  Future<void> oublier() async {
    if (!disponible || !_initialise) {
      return;
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Rien à faire : la session locale est effacée par ailleurs.
    }
  }
}
