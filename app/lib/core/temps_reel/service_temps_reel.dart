import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../storage/session_store.dart';
import 'message_temps_reel.dart';

/// Connexion temps réel à un événement (§9).
///
/// Une interface : les écrans se testent sans serveur, et le temps réel n'est jamais la
/// source de vérité (`RG-RT-03`) — une doublure inerte doit laisser l'application
/// parfaitement fonctionnelle, seulement moins vivante.
abstract interface class ServiceTempsReel {
  /// Ouvre la connexion sur cet événement. Idempotente sur le même identifiant.
  Future<void> connecter(String evenementId);

  /// Ferme la connexion courante.
  Future<void> deconnecter();

  /// Messages reçus, et rien d'autre.
  Stream<MessageTempsReel> get messages;

  /// Émet à chaque reconnexion réussie.
  ///
  /// Signalée à part des messages parce qu'elle impose un rechargement complet et non
  /// une relecture ciblée : ce qui a été manqué pendant la coupure est par définition
  /// inconnu (`RG-RT-03`).
  Stream<void> get reconnexions;
}

/// Implémentation SignalR.
///
/// Toute opération est sans effet si la connexion échoue : une soirée reste exacte sans
/// temps réel, elle exige seulement une actualisation manuelle. Aucune méthode ne lève —
/// un écran qui s'ouvrirait en erreur parce que le hub est injoignable serait pire que
/// pas de temps réel du tout.
class ServiceTempsReelSignalR implements ServiceTempsReel {
  ServiceTempsReelSignalR({
    required String baseUrl,
    required SessionStore sessions,
  }) : _baseUrl = baseUrl,
       _sessions = sessions;

  final String _baseUrl;
  final SessionStore _sessions;

  final _messages = StreamController<MessageTempsReel>.broadcast();
  final _reconnexions = StreamController<void>.broadcast();

  HubConnection? _connexion;
  String? _evenementCourant;

  @override
  Stream<MessageTempsReel> get messages => _messages.stream;

  @override
  Stream<void> get reconnexions => _reconnexions.stream;

  @override
  Future<void> connecter(String evenementId) async {
    if (_evenementCourant == evenementId && _connexion != null) {
      return;
    }

    await deconnecter();

    // L'identifiant de l'événement est dans l'adresse : le hub doit pouvoir filtrer
    // avant le premier message, et une méthode d'abonnement laisserait une fenêtre où
    // la connexion est établie sans être restreinte.
    final adresse = '$_baseUrl/hubs/event?eventId=$evenementId';

    final connexion = HubConnectionBuilder()
        .withUrl(
          adresse,
          options: HttpConnectionOptions(
            // Le jeton est relu à chaque tentative : il ne vit que quinze minutes, et
            // une reconnexion présentant un jeton périmé échouerait indéfiniment.
            accessTokenFactory: () async =>
                await _sessions.lireJetonAcces() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    connexion.on('Changement', (arguments) {
      if (arguments == null || arguments.isEmpty) {
        return;
      }

      final nom = arguments.first;

      if (nom is! String) {
        return;
      }

      _messages.add(
        MessageTempsReel(
          nom: nom,
          charge: arguments.length > 1 ? arguments[1] : null,
        ),
      );
    });

    connexion.onreconnected(({String? connectionId}) {
      _reconnexions.add(null);
    });

    try {
      await connexion.start();
      _connexion = connexion;
      _evenementCourant = evenementId;
    } catch (_) {
      // Pas de temps réel. Capture large et non « on Exception » : sans plateforme, ou
      // sur une adresse invalide, l'appel peut lever une Error.
      _connexion = null;
      _evenementCourant = null;
    }
  }

  @override
  Future<void> deconnecter() async {
    final connexion = _connexion;
    _connexion = null;
    _evenementCourant = null;

    if (connexion == null) {
      return;
    }

    try {
      await connexion.stop();
    } catch (_) {
      // Rien à faire : la connexion est abandonnée de toute façon.
    }
  }
}
