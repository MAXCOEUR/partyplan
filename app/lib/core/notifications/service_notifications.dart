import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/appareils_api.dart';
import 'lien_notification.dart';

/// Où en est le consentement de cette personne.
enum EtatNotifications {
  /// Rien n'a été demandé : c'est le seul cas où l'on propose quelque chose.
  aDemander,

  accorde,

  /// Refusé au niveau système. L'application ne peut pas redemander : reproposer le
  /// geste donnerait un bouton sans effet.
  refuse,

  /// Firebase n'est pas configuré sur cette compilation. Aucune notification n'est
  /// possible, et il n'y a rien à proposer (règle 5).
  indisponible,
}

/// Notifications poussées, côté application.
///
/// Une interface plutôt qu'une classe concrète : les écrans se testent sans Firebase,
/// qui exige une plateforme réelle et une configuration de projet.
abstract interface class ServiceNotifications {
  Future<EtatNotifications> etatCourant();

  /// Demande la permission puis enregistre le jeton. Sans effet si déjà refusé.
  Future<void> demanderEtEnregistrer();

  /// Retire l'appareil courant. À appeler **avant** de purger la session, sinon l'appel
  /// n'est plus authentifié.
  Future<void> retirerAppareilCourant();

  /// Réenregistre le jeton à chaque rotation. FCM en change sans prévenir, et un jeton
  /// périmé est une personne qui ne reçoit plus rien, sans erreur visible.
  Future<void> ecouterRafraichissements();

  /// Ouvre la destination portée par une notification tapée.
  ///
  /// Déclarée ici dès maintenant, implémentée à la tâche 7 : c'est l'interface que les
  /// écrans voient, et la compléter plus tard casserait toutes les doublures de test.
  Future<void> ecouterOuvertures(void Function(String destination) aller);
}

/// Implémentation Firebase.
///
/// Toute opération est sans effet si l'initialisation a échoué : c'est le cas d'un clone
/// sans `google-services.json`, qui doit rester utilisable (règle 5).
class ServiceNotificationsFirebase implements ServiceNotifications {
  ServiceNotificationsFirebase(this._api);

  final AppareilsApi _api;

  bool? _disponible;

  static const _cleApi = String.fromEnvironment('FIREBASE_API_KEY');

  /// Jeton de l'appareil. Sur le Web, `getToken` exige la clé VAPID : sans elle le
  /// navigateur refuse d'émettre un jeton, silencieusement.
  static Future<String?> _jetonCourant() => kIsWeb
      ? FirebaseMessaging.instance.getToken(
          vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
        )
      : FirebaseMessaging.instance.getToken();

  Future<bool> _initialiser() async {
    if (_disponible != null) {
      return _disponible!;
    }

    try {
      if (Firebase.apps.isEmpty) {
        // Sur le Web il n'y a pas de google-services.json : les options doivent être
        // fournies explicitement, et sans elles il n'y a rien à initialiser. Sur
        // Android le fichier suffit, et cette branche y renverrait faussement
        // « indisponible ».
        if (kIsWeb) {
          if (_cleApi.isEmpty) {
            _disponible = false;
            return false;
          }

          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _cleApi,
              projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
              messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
              appId: String.fromEnvironment('FIREBASE_APP_ID'),
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      _disponible = true;
    } catch (_) {
      // Aucune configuration Firebase dans cette compilation. Ce n'est pas une erreur.
      //
      // Capture large et non « on Exception » : sans liaison de plateforme, l'appel lève
      // une Error et non une Exception. C'est le cas d'un clone sans google-services.json
      // et celui des tests, où une déconnexion échouait faute d'être attrapée ici.
      _disponible = false;
    }

    return _disponible!;
  }

  @override
  Future<EtatNotifications> etatCourant() async {
    if (!await _initialiser()) {
      return EtatNotifications.indisponible;
    }

    final reglages = await FirebaseMessaging.instance.getNotificationSettings();

    return switch (reglages.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => EtatNotifications.accorde,
      AuthorizationStatus.denied => EtatNotifications.refuse,
      _ => EtatNotifications.aDemander,
    };
  }

  @override
  Future<void> demanderEtEnregistrer() async {
    if (!await _initialiser()) {
      return;
    }

    final reglages = await FirebaseMessaging.instance.requestPermission();

    if (reglages.authorizationStatus != AuthorizationStatus.authorized &&
        reglages.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    await _envoyerJeton();
  }

  @override
  Future<void> ecouterRafraichissements() async {
    if (!await _initialiser()) {
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((jeton) async {
      try {
        await _api.enregistrer(jeton, plateforme: _plateforme);
      } on Exception {
        // Le jeton repartira au prochain lancement : échouer ici ne doit rien
        // interrompre.
      }
    });
  }

  @override
  Future<void> retirerAppareilCourant() async {
    if (!await _initialiser()) {
      return;
    }

    try {
      final jeton = await _jetonCourant();
      if (jeton != null) {
        await _api.retirer(jeton);
      }
    } on Exception {
      // Une déconnexion ne doit jamais échouer à cause d'une notification.
    }
  }

  Future<void> _envoyerJeton() async {
    try {
      final jeton = await _jetonCourant();
      if (jeton != null) {
        await _api.enregistrer(jeton, plateforme: _plateforme);
      }
    } on Exception {
      // Sans effet visible : la personne a accordé la permission, le jeton repartira au
      // prochain lancement.
    }
  }

  @override
  Future<void> ecouterOuvertures(
    void Function(String destination) aller,
  ) async {
    if (!await _initialiser()) {
      return;
    }

    // Deux chemins, et le second est celui qu'on oublie : l'application déjà lancée reçoit
    // par onMessageOpenedApp ; l'application démarrée *par* la notification ne reçoit rien
    // et doit interroger getInitialMessage. C'est pourtant le cas d'un rappel reçu la
    // veille, donc le plus fréquent.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final destination = LienNotification.destination(message.data);
      if (destination != null) {
        aller(destination);
      }
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final destination = LienNotification.destination(initial?.data);
    if (destination != null) {
      aller(destination);
    }
  }

  static String get _plateforme => kIsWeb ? 'web' : 'android';
}
