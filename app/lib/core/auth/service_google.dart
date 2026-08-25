import 'dart:async';

import 'package:flutter/foundation.dart';
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
  /// propre bouton, rendu par le SDK de Google. Les deux chemins existent donc, et
  /// c'est cette valeur qui décide de la forme du bouton affiché.
  bool get parcoursProgrammatique;

  /// Prépare le client. Idempotente, et sans effet si rien n'est configuré.
  ///
  /// Nécessaire avant d'afficher le bouton rendu par Google : celui-ci est produit par
  /// le SDK, qui doit être initialisé.
  Future<void> preparer();

  /// Jetons d'identité arrivant sans qu'on les ait demandés.
  ///
  /// C'est par là que passe le bouton rendu par Google sur le Web : la personne clique
  /// dans un élément que le SDK contrôle, et le résultat revient par ce flux. Sur
  /// Android le flux existe aussi, alimenté par les mêmes événements.
  Stream<String> get jetons;

  /// Demande la permission puis renvoie le jeton. `null` si annulé ou indisponible.
  ///
  /// Sans effet sur le Web, où le parcours programmatique est refusé : utiliser
  /// [jetons] et le bouton rendu.
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
  ///
  /// C'est l'identifiant du client **Web** de la console Google Cloud, sur les deux
  /// plateformes : sur le Web il identifie l'application, sur Android il sert
  /// d'audience au jeton que l'API vérifiera.
  static const _depuisLaCompilation = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  final String _identifiantClient;

  final StreamController<String> _jetons = StreamController<String>.broadcast();

  Future<bool>? _preparation;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _ecoute;

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
  Stream<String> get jetons => _jetons.stream;

  @override
  Future<void> preparer() => _initialiser();

  /// Initialise une seule fois. `initialize` lève si elle est appelée deux fois, et
  /// deux écrans peuvent légitimement demander la préparation : le résultat est donc
  /// mémorisé, échec compris.
  Future<bool> _initialiser() => _preparation ??= _initialiserVraiment();

  Future<bool> _initialiserVraiment() async {
    if (!disponible) {
      return false;
    }

    try {
      // Deux plateformes, deux paramètres, et les mélanger échoue. Sur le Web,
      // `serverClientId` est refusé par une assertion du greffon. Sur Android,
      // `clientId` est ignoré et l'application est reconnue par le nom de son paquet
      // et l'empreinte de son certificat — `google-services.json` suffit, et
      // `serverClientId` ne sert qu'à fixer explicitement l'audience du jeton.
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? _identifiantClient : null,
        serverClientId: kIsWeb ? null : _identifiantClient,
      );

      _ecoute = GoogleSignIn.instance.authenticationEvents.listen(
        (evenement) {
          if (evenement is GoogleSignInAuthenticationEventSignIn) {
            final jeton = evenement.user.authentication.idToken;
            if (jeton != null) {
              _jetons.add(jeton);
            }
          }
        },
        // Une erreur du SDK ne doit pas fermer le flux : l'écran resterait muet
        // jusqu'au prochain lancement.
        onError: (Object _) {},
      );

      return true;
    } catch (_) {
      // Aucune configuration Google dans cette compilation, ou pas de plateforme.
      //
      // Capture large et non « on Exception » : sans liaison de plateforme, l'appel
      // lève une Error et non une Exception.
      return false;
    }
  }

  @override
  Future<String?> obtenirJetonIdentite() async {
    if (!await _initialiser() || !parcoursProgrammatique) {
      return null;
    }

    try {
      final compte = await GoogleSignIn.instance.authenticate();

      return compte.authentication.idToken;
    } catch (_) {
      // Annulation, absence de services Google Play, configuration incomplète : dans
      // tous les cas la personne se connecte par mot de passe.
      return null;
    }
  }

  @override
  Future<void> oublier() async {
    if (_preparation == null || !await _initialiser()) {
      return;
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Rien à faire : la session locale est effacée par ailleurs.
    }
  }

  /// Libère l'écoute. Appelée par le conteneur de providers.
  Future<void> fermer() async {
    await _ecoute?.cancel();
    await _jetons.close();
  }
}
