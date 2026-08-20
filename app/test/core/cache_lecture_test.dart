import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/cache_lecture.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('CacheLecture', () {
    test('la clé ne dépend pas de l’ordre des paramètres', () {
      final cache = CacheLecture(MagasinLocalDouble());

      // Deux requêtes équivalentes ne doivent pas produire deux entrées : l'ordre
      // d'insertion d'une Map n'est pas significatif pour l'API.
      expect(
        cache.cle('/events', {'b': 2, 'a': 1}),
        cache.cle('/events', {'a': 1, 'b': 2}),
      );
    });

    test('la clé distingue deux chemins', () {
      final cache = CacheLecture(MagasinLocalDouble());

      expect(cache.cle('/events', null), isNot(cache.cle('/events/42', null)));
    });

    test('relit la charge et la date de réception', () async {
      final magasin = MagasinLocalDouble();
      final cache = CacheLecture(magasin);
      final recuA = DateTime.utc(2026, 8, 20, 14, 32);

      await cache.enregistrer('/events', null, [
        {'id': 'a', 'name': 'Crémaillère'},
      ], recuA);

      final entree = await cache.lire('/events', null);

      expect(entree, isNotNull);
      expect(entree!.recuA, recuA);
      expect((entree.charge! as List).first, {
        'id': 'a',
        'name': 'Crémaillère',
      });
    });

    test('renvoie null quand rien n’a été mis en cache', () async {
      final cache = CacheLecture(MagasinLocalDouble());

      expect(await cache.lire('/events', null), isNull);
    });

    test('purge tout le cache sans toucher aux autres clés', () async {
      final magasin = MagasinLocalDouble();
      final cache = CacheLecture(magasin);
      await magasin.ecrire('pp_file|1', 'écriture en attente');
      await cache.enregistrer('/events', null, [], DateTime.utc(2026));

      await cache.purger();

      expect(await cache.lire('/events', null), isNull);
      // La file d'écritures survit à la purge du cache : ce sont des actions de
      // l'utilisateur qui ne sont pas encore parties, pas des données rechargeables.
      expect(await magasin.lire('pp_file|1'), 'écriture en attente');
    });
  });
}
