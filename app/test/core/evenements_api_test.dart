import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/network/evenements_api.dart';

void main() {
  group('EvenementDeLaListe', () {
    test('analyse la réponse de la liste', () {
      final item = EvenementDeLaListe.depuisJson({
        'id': '0198-uuid',
        'name': 'Crémaillère chez Léa',
        'startsAt': '2026-09-12T20:00:00+02:00',
        'endsAt': null,
        'address': '12 rue des Lilas, Lyon',
        'coverImageUrl': null,
        'invited': 8,
        'present': 5,
        'myRole': 'Owner',
        'myStatus': 'Going',
        'isPast': false,
      });

      expect(item.nom, 'Crémaillère chez Léa');
      expect(item.debut.toUtc(), DateTime.utc(2026, 9, 12, 18));
      expect(item.monRole, RoleMembre.proprietaire);
      expect(item.monStatut, StatutPresence.present);
      expect(item.estPasse, isFalse);
    });

    test('le caractère passé vient du serveur, jamais recalculé', () {
      // L'horloge d'un téléphone peut être fausse : une soirée passerait alors du
      // mauvais côté de la liste.
      final item = _item(debut: '2050-01-01T20:00:00Z', estPasse: true);

      expect(item.estPasse, isTrue);
    });
  });

  group('ResumeEvenement', () {
    test('analyse le détail', () {
      final resume = ResumeEvenement.depuisJson({
        'id': 'a',
        'name': 'Crémaillère',
        'description': null,
        'startsAt': '2026-09-12T20:00:00+02:00',
        'endsAt': null,
        'address': null,
        'coverImageUrl': null,
        'memberCount': 8,
        'presentCount': 5,
        'maybeCount': 2,
        'joinEnabled': true,
      });

      expect(resume.nombrePresents, 5);
      expect(resume.nombrePeutEtre, 2);
      expect(resume.adhesionsOuvertes, isTrue);
    });

    test('EF-EVT-02 : sans fin saisie, la fin est implicite à +12 heures', () {
      final resume = ResumeEvenement.depuisJson({
        'id': 'a',
        'name': 'Crémaillère',
        'description': null,
        'startsAt': '2026-09-12T20:00:00Z',
        'endsAt': null,
        'address': null,
        'coverImageUrl': null,
        'memberCount': 1,
        'presentCount': 1,
        'maybeCount': 0,
        'joinEnabled': true,
      });

      expect(resume.finEffective.toUtc(), DateTime.utc(2026, 9, 13, 8));
    });
  });

  group('StatutPresence', () {
    test('traduit les six statuts de l’API', () {
      expect(StatutPresence.depuisApi('Going'), StatutPresence.present);
      expect(StatutPresence.depuisApi('Maybe'), StatutPresence.peutEtre);
      expect(StatutPresence.depuisApi('NotGoing'), StatutPresence.absent);
      expect(StatutPresence.depuisApi('Late'), StatutPresence.enRetard);
      expect(StatutPresence.depuisApi('EarlyLeave'), StatutPresence.partAvant);
      expect(StatutPresence.depuisApi('Unknown'), StatutPresence.inconnu);
    });

    test('un statut inconnu de l’API ne fait pas planter l’écran', () {
      expect(StatutPresence.depuisApi('Teleportation'), StatutPresence.inconnu);
      expect(StatutPresence.depuisApi(null), StatutPresence.inconnu);
    });

    test('RG-PRES-02 : en retard et part plus tôt comptent comme présents', () {
      expect(StatutPresence.enRetard.compteCommePresent, isTrue);
      expect(StatutPresence.partAvant.compteCommePresent, isTrue);
      expect(StatutPresence.peutEtre.compteCommePresent, isFalse);
      expect(StatutPresence.inconnu.compteCommePresent, isFalse);
    });
  });

  group('Membre', () {
    test('EF-PRES-06 : les têtes comptent la personne et ses accompagnants', () {
      expect(_membre(StatutPresence.present, accompagnants: 2).tetes, 3);
      expect(_membre(StatutPresence.enRetard, accompagnants: 1).tetes, 2);
    });

    test('RG-PRES-04 : un absent n’apporte aucune tête', () {
      expect(_membre(StatutPresence.absent, accompagnants: 4).tetes, 0);
      expect(_membre(StatutPresence.peutEtre, accompagnants: 4).tetes, 0);
    });

    test('l’identifiant de compte n’est pas exposé, seulement le fait d’en avoir un', () {
      final membre = Membre.depuisJson({
        'id': 'm1',
        'displayName': 'Léa',
        'avatarUrl': null,
        'status': 'Going',
        'arrivalTime': null,
        'departureTime': null,
        'extraGuests': 0,
        'role': 'Member',
        'hasAccount': true,
        'isMe': false,
      });

      expect(membre.aUnCompte, isTrue);
      expect(membre.cestMoi, isFalse);
    });
  });

  group('RoleMembre', () {
    test('RG-ROLE-01 : seul le propriétaire supprime', () {
      expect(RoleMembre.proprietaire.peutSupprimer, isTrue);
      expect(RoleMembre.administrateur.peutSupprimer, isFalse);
      expect(RoleMembre.administrateur.peutGerer, isTrue);
      expect(RoleMembre.membre.peutGerer, isFalse);
    });
  });

  group('ApercuInvitation', () {
    test('RG-INV-04 : le modèle ne porte ni membres ni dépenses', () {
      final apercu = ApercuInvitation.depuisJson({
        'name': 'Crémaillère',
        'startsAt': '2026-09-12T20:00:00Z',
        'endsAt': null,
        'address': 'Lyon',
        'description': null,
        'participantCount': 8,
        'joinEnabled': true,
        'alreadyMember': false,
      });

      expect(apercu.nombreParticipants, 8);
      expect(apercu.adhesionsOuvertes, isTrue);
    });
  });

  group('Normalisation du code court', () {
    test('tolère minuscules, espaces, tirets et absence de préfixe', () {
      for (final saisie in [
        'PLAN-K7M2X9',
        'plan-k7m2x9',
        ' plan k7m 2x9 ',
        'K7M2X9',
        'k7m-2x9',
      ]) {
        expect(EvenementsApi.normaliserCode(saisie), 'K7M2X9', reason: saisie);
      }
    });
  });
}

EvenementDeLaListe _item({required String debut, required bool estPasse}) =>
    EvenementDeLaListe.depuisJson({
      'id': 'a',
      'name': 'Test',
      'startsAt': debut,
      'endsAt': null,
      'address': null,
      'coverImageUrl': null,
      'invited': 1,
      'present': 1,
      'myRole': 'Member',
      'myStatus': 'Unknown',
      'isPast': estPasse,
    });

Membre _membre(StatutPresence statut, {int accompagnants = 0}) => Membre(
  id: 'm',
  nomAffiche: 'Test',
  avatarUrl: null,
  statut: statut,
  heureArrivee: null,
  heureDepart: null,
  accompagnants: accompagnants,
  role: RoleMembre.membre,
  aUnCompte: false,
  cestMoi: false,
);
