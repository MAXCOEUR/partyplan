import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/temps_reel/message_temps_reel.dart';

/// Le classement d'un message décide de ce qui est relu. Se tromper ici laisse un écran
/// faux sans qu'aucune erreur n'apparaisse.
void main() {
  group('MessageTempsReel', () {
    test('classe les messages par famille', () {
      expect(
        const MessageTempsReel(nom: 'member.joined').toucheMembres,
        isTrue,
      );
      expect(const MessageTempsReel(nom: 'item.claimed').toucheCourses, isTrue);
      expect(
        const MessageTempsReel(nom: 'expense.created').toucheDepenses,
        isTrue,
      );
      expect(
        const MessageTempsReel(nom: 'balances.changed').toucheSoldes,
        isTrue,
      );
      // Un règlement change les soldes : le classer ailleurs laisserait l'écran des
      // remboursements périmé.
      expect(
        const MessageTempsReel(nom: 'settlement.marked').toucheSoldes,
        isTrue,
      );
      expect(
        const MessageTempsReel(nom: 'message.created').toucheDiscussion,
        isTrue,
      );
      expect(const MessageTempsReel(nom: 'poll.voted').toucheSondages, isTrue);
      expect(
        const MessageTempsReel(nom: 'event.updated').toucheEvenement,
        isTrue,
      );
    });

    test('un message inconnu ne touche rien', () {
      // Le serveur peut diffuser un message qu'une application ancienne ignore : elle
      // doit le laisser passer sans rien relire, et surtout sans lever.
      const inconnu = MessageTempsReel(nom: 'quelquechose.denouveau');

      expect(inconnu.toucheMembres, isFalse);
      expect(inconnu.toucheCourses, isFalse);
      expect(inconnu.toucheSoldes, isFalse);
    });
  });
}
