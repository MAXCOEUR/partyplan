import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';

void main() {
  group('Activite.depuisJson', () {
    test('lit une ligne complète', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'memberId': 'm1',
        'actorName': 'Camille',
        'avatarUrl': null,
        'kind': 'item.claimed',
        'donnees': {'libelle': 'Glaçons'},
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.id, 'a1');
      expect(activite.membreId, 'm1');
      expect(activite.auteur, 'Camille');
      expect(activite.categorie, 'item.claimed');
      expect(activite.texte('libelle'), 'Glaçons');
    });

    test('accepte une ligne sans données', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'member.joined',
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.texte('libelle'), isNull);
      expect(activite.montant('montant'), isNull);
      expect(activite.liste('champs'), isEmpty);
    });

    test('ne plante pas sur un champ absent du payload', () {
      // Une entrée écrite par une version antérieure du serveur ne doit jamais casser
      // l'écran : le fil est en ajout seul, ces lignes ne seront jamais corrigées.
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'expense.created',
        'donnees': {'libelle': 'Courses'},
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.texte('libelle'), 'Courses');
      expect(activite.montant('montant'), isNull);
    });

    test('lit un montant entier comme un montant décimal', () {
      // Le serveur envoie 20 et non 20.0 lorsque le montant est rond : le lire en int
      // ferait échouer la conversion et masquerait le montant.
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'settlement.marked',
        'donnees': {'de': 'Alex', 'vers': 'Camille', 'montant': 20},
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.montant('montant'), 20.0);
    });

    test('lit la liste des champs modifiés', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'event.date_or_place_changed',
        'donnees': {
          'champs': ['date', 'lieu'],
        },
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.liste('champs'), ['date', 'lieu']);
    });

    test('convertit l’horodatage en heure locale', () {
      final activite = Activite.depuisJson(const {
        'id': 'a1',
        'actorName': 'Camille',
        'kind': 'member.joined',
        'createdAt': '2026-08-26T18:30:00Z',
      });

      expect(activite.creeLe.isUtc, isFalse);
    });
  });

  group('PageActivite.depuisJson', () {
    test('lit les lignes et le drapeau de suite', () {
      final page = PageActivite.depuisJson(const {
        'items': [
          {
            'id': 'a1',
            'actorName': 'Camille',
            'kind': 'member.joined',
            'createdAt': '2026-08-26T18:30:00Z',
          },
        ],
        'hasMore': true,
      });

      expect(page.lignes, hasLength(1));
      expect(page.encore, isTrue);
    });

    test('accepte une page vide', () {
      final page = PageActivite.depuisJson(const {
        'items': [],
        'hasMore': false,
      });

      expect(page.lignes, isEmpty);
      expect(page.encore, isFalse);
    });
  });
}
