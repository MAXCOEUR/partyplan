import 'package:flutter_test/flutter_test.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('MagasinLocal', () {
    test('relit ce qui a été écrit', () async {
      final magasin = MagasinLocalDouble();

      await magasin.ecrire('a', 'valeur');

      expect(await magasin.lire('a'), 'valeur');
    });

    test('renvoie null sur une clé absente', () async {
      expect(await MagasinLocalDouble().lire('absente'), isNull);
    });

    test('supprime par préfixe sans toucher au reste', () async {
      final magasin = MagasinLocalDouble();
      await magasin.ecrire('cache|a', '1');
      await magasin.ecrire('cache|b', '2');
      await magasin.ecrire('file|c', '3');

      await magasin.supprimerPrefixe('cache|');

      expect(await magasin.lire('cache|a'), isNull);
      expect(await magasin.lire('cache|b'), isNull);
      expect(await magasin.lire('file|c'), '3');
    });
  });
}
