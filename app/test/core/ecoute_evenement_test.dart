import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/temps_reel/ecoute_evenement.dart';
import 'package:partyplan/core/temps_reel/message_temps_reel.dart';
import 'package:partyplan/core/temps_reel/service_temps_reel.dart';

/// Un message reçu doit provoquer une relecture, sinon le temps réel ne sert à rien.
void main() {
  group('EcouteEvenement', () {
    test('un message diffusé provoque une relecture', () async {
      var relectures = 0;
      final service = _ServiceDouble();
      final ecoute = EcouteEvenement(invalider: () => relectures++)
        ..demarrer(service);

      service.emettre(const MessageTempsReel(nom: 'member.statusChanged'));
      await Future<void>.delayed(Duration.zero);

      expect(relectures, 1);

      await ecoute.arreter();
    });

    test('une reconnexion provoque une relecture', () async {
      // RG-RT-03 : ce qui a été manqué pendant la coupure est inconnu, donc on
      // recharge tout plutôt que de deviner.
      var relectures = 0;
      final service = _ServiceDouble();
      final ecoute = EcouteEvenement(invalider: () => relectures++)
        ..demarrer(service);

      service.reconnecter();
      await Future<void>.delayed(Duration.zero);

      expect(relectures, 1);

      await ecoute.arreter();
    });

    test('après arrêt, plus rien ne relit', () async {
      // Sans cela, quitter une soirée laisserait une écoute vivante qui invaliderait
      // les providers d'un écran disparu — à chaque soirée ouverte, une écoute de plus.
      var relectures = 0;
      final service = _ServiceDouble();
      final ecoute = EcouteEvenement(invalider: () => relectures++)
        ..demarrer(service);

      await ecoute.arreter();
      service.emettre(const MessageTempsReel(nom: 'item.created'));
      await Future<void>.delayed(Duration.zero);

      expect(relectures, 0);
    });
  });
}

class _ServiceDouble implements ServiceTempsReel {
  final _messages = StreamController<MessageTempsReel>.broadcast();
  final _reconnexions = StreamController<void>.broadcast();

  void emettre(MessageTempsReel m) => _messages.add(m);
  void reconnecter() => _reconnexions.add(null);

  @override
  Stream<MessageTempsReel> get messages => _messages.stream;

  @override
  Stream<void> get reconnexions => _reconnexions.stream;

  @override
  Future<void> connecter(String evenementId) async {}

  @override
  Future<void> deconnecter() async {}
}
