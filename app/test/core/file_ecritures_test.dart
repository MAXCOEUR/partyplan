import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/file_ecritures.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('FileEcritures', () {
    test('conserve l’ordre d’inscription', () async {
      final file = FileEcritures(MagasinLocalDouble());

      await file.inscrire(
        methode: 'POST',
        chemin: '/join/abc',
        corps: {'a': 1},
      );
      await file.inscrire(methode: 'PATCH', chemin: '/events/1/members/me');

      final attente = await file.enAttente();

      expect(attente.map((e) => e.chemin), [
        '/join/abc',
        '/events/1/members/me',
      ]);
    });

    test(
      'la clé d’idempotence est fixée à l’inscription et ne change plus',
      () async {
        final magasin = MagasinLocalDouble();
        final file = FileEcritures(magasin);

        final inscrite = await file.inscrire(
          methode: 'POST',
          chemin: '/join/abc',
        );

        // Relecture depuis le magasin : c'est le chemin qu'emprunte un rejeu après
        // redémarrage de l'application. Une clé régénérée ici ne serait plus reconnue
        // par l'idempotence du serveur, et le rejeu créerait un doublon.
        final relue = (await FileEcritures(magasin).enAttente()).single;

        expect(relue.cleIdempotence, inscrite.cleIdempotence);
        expect(relue.cleIdempotence, isNotEmpty);
      },
    );

    test('deux inscriptions portent deux clés distinctes', () async {
      final file = FileEcritures(MagasinLocalDouble());

      final a = await file.inscrire(methode: 'POST', chemin: '/join/abc');
      final b = await file.inscrire(methode: 'POST', chemin: '/join/abc');

      expect(a.cleIdempotence, isNot(b.cleIdempotence));
    });

    test('retirer sort une écriture et laisse les autres', () async {
      final file = FileEcritures(MagasinLocalDouble());
      final a = await file.inscrire(methode: 'POST', chemin: '/a');
      await file.inscrire(methode: 'POST', chemin: '/b');

      await file.retirer(a.id);

      expect((await file.enAttente()).map((e) => e.chemin), ['/b']);
    });

    test('compte les tentatives', () async {
      final file = FileEcritures(MagasinLocalDouble());
      final a = await file.inscrire(methode: 'POST', chemin: '/a');

      await file.incrementerTentatives(a.id);
      await file.incrementerTentatives(a.id);

      expect((await file.enAttente()).single.tentatives, 2);
    });

    test('le corps est restitué à l’identique après relecture', () async {
      final magasin = MagasinLocalDouble();
      await FileEcritures(magasin).inscrire(
        methode: 'PATCH',
        chemin: '/events/1/members/me',
        corps: {'status': 'Going', 'extraGuests': 2},
      );

      final relue = (await FileEcritures(magasin).enAttente()).single;

      expect(relue.corps, {'status': 'Going', 'extraGuests': 2});
    });
  });
}
