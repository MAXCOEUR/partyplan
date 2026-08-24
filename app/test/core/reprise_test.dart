import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/network/reprise.dart';

void main() {
  group('Politique de reprise', () {
    test('un refus ne se retente pas', () {
      // Riverpod 3 réessaie par défaut tout provider en échec, avec un délai qui
      // double. Sur un refus d'autorisation, ces tentatives ne peuvent pas aboutir : le
      // serveur donne six fois la même réponse et l'écran reste sur son indicateur de
      // chargement — c'est le « chargement infini » de l'administration.
      expect(
        repriseApres(1, const ApiException(statusCode: 403, title: 'Refusé')),
        isNull,
      );
    });

    test('une ressource absente ni une demande invalide ne se retentent', () {
      expect(
        repriseApres(1, const ApiException(statusCode: 404, title: 'Absent')),
        isNull,
      );
      expect(
        repriseApres(1, const ApiException(statusCode: 400, title: 'Invalide')),
        isNull,
      );
    });

    test('une panne du serveur se retente, en espaçant', () {
      // Un 502 le temps d'un redéploiement, un 503 sous la charge : celui-là passera
      // peut-être à la tentative suivante.
      final premier = repriseApres(
        1,
        const ApiException(statusCode: 503, title: 'Indisponible'),
      );
      final second = repriseApres(
        2,
        const ApiException(statusCode: 503, title: 'Indisponible'),
      );

      expect(premier, isNotNull);
      expect(second, greaterThan(premier!));
    });

    test('une coupure réseau se retente', () {
      // Sans code de statut : la requête n'a pas atteint le serveur.
      expect(
        repriseApres(1, const ApiException(statusCode: 0, title: 'Hors ligne')),
        isNotNull,
      );
    });

    test('les tentatives s’arrêtent', () {
      // Sans borne, un serveur durablement éteint fait tourner l'écran indéfiniment.
      expect(
        repriseApres(9, const ApiException(statusCode: 503, title: 'Indispo')),
        isNull,
      );
    });

    test('une erreur inattendue se retente une fois, puis renonce', () {
      expect(repriseApres(1, StateError('imprévu')), isNotNull);
      expect(repriseApres(9, StateError('imprévu')), isNull);
    });
  });
}
