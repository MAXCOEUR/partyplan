import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/core/network/activite_api.dart';
import 'package:partyplan/core/providers.dart';

/// Doublure d'API rendant des pages contrôlées.
///
/// Le fil est simulé comme un registre réel : des lignes ordonnées du plus récent au
/// plus ancien, dans lequel de nouvelles lignes peuvent apparaître en tête pendant
/// qu'on remonte le passé.
class _ApiDouble implements ActiviteApi {
  _ApiDouble(this.lignes);

  /// Toutes les lignes du serveur, de la plus récente à la plus ancienne.
  List<Activite> lignes;

  int appels = 0;

  /// Fait lever la prochaine lecture, pour éprouver le rattrapage d'erreur.
  bool echoue = false;

  @override
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) async {
    appels++;

    if (echoue) {
      throw Exception('réseau');
    }

    var depart = 0;
    if (avant != null) {
      final rang = lignes.indexWhere((l) => l.id == avant);
      depart = rang == -1 ? lignes.length : rang + 1;
    }

    final tranche = lignes.skip(depart).take(limite).toList();

    return PageActivite(
      lignes: tranche,
      encore: depart + tranche.length < lignes.length,
    );
  }
}

Activite _ligne(int rang) => Activite(
  id: 'a$rang',
  auteur: 'Camille',
  categorie: 'item.created',
  donnees: {'libelle': 'Article $rang'},
  // Décroissant : le rang 1 est le plus récent.
  creeLe: DateTime(2026, 8, 26, 18, 30).subtract(Duration(minutes: rang)),
);

List<Activite> _lignes(int combien, {int depuis = 1}) => [
  for (var i = depuis; i < depuis + combien; i++) _ligne(i),
];

ProviderContainer _conteneur(_ApiDouble api) {
  final conteneur = ProviderContainer(
    overrides: [activiteApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);
  return conteneur;
}

void main() {
  group('Pagination du fil d’activité', () {
    test('la première page rend les lignes les plus récentes', () async {
      final api = _ApiDouble(_lignes(45));
      final conteneur = _conteneur(api);

      final page = await conteneur.read(filActiviteProvider('e1').future);

      expect(page.lignes.map((l) => l.id), _lignes(30).map((l) => l.id));
      expect(page.encore, isTrue);
    });

    test('remonter ajoute les lignes plus anciennes à la suite', () async {
      final api = _ApiDouble(_lignes(45));
      final conteneur = _conteneur(api);

      await conteneur.read(filActiviteProvider('e1').future);
      await conteneur
          .read(filActiviteProvider('e1').notifier)
          .chargerPlusAncien();

      final page = conteneur.read(filActiviteProvider('e1')).value!;

      expect(page.lignes, hasLength(45));
      expect(page.encore, isFalse);
    });

    test('une ligne neuve pendant la remontée ne fait perdre aucune ligne', () async {
      // Le défaut trouvé en revue : la première page était relue et concaténée devant
      // les pages remontées. Une ligne neuve poussait la trentième hors de la fenêtre,
      // et elle disparaissait du milieu du registre — sans trou visible, puisque le
      // filet est continu. Sur la trace de référence en cas de désaccord sur les
      // montants, c'est le pire défaut possible.
      final api = _ApiDouble(_lignes(45));
      final conteneur = _conteneur(api);

      await conteneur.read(filActiviteProvider('e1').future);
      await conteneur
          .read(filActiviteProvider('e1').notifier)
          .chargerPlusAncien();

      // Quelqu'un coche un article : une ligne apparaît en tête côté serveur.
      api.lignes = [_ligne(0), ...api.lignes];
      await conteneur.read(filActiviteProvider('e1').notifier).rafraichir();

      final page = conteneur.read(filActiviteProvider('e1')).value!;
      final identifiants = page.lignes.map((l) => l.id).toList();

      expect(
        identifiants.first,
        'a0',
        reason: 'la ligne neuve doit être en tête',
      );
      expect(
        identifiants,
        hasLength(46),
        reason: 'aucune ligne ne doit disparaître',
      );
      expect(
        identifiants.toSet(),
        hasLength(46),
        reason: 'aucune ligne ne doit apparaître deux fois',
      );

      for (var rang = 1; rang <= 45; rang++) {
        expect(
          identifiants,
          contains('a$rang'),
          reason: 'la ligne a$rang a disparu du registre',
        );
      }
    });

    test('l’ordre reste du plus récent au plus ancien après fusion', () async {
      final api = _ApiDouble(_lignes(45));
      final conteneur = _conteneur(api);

      await conteneur.read(filActiviteProvider('e1').future);
      await conteneur
          .read(filActiviteProvider('e1').notifier)
          .chargerPlusAncien();

      api.lignes = [_ligne(0), ...api.lignes];
      await conteneur.read(filActiviteProvider('e1').notifier).rafraichir();

      final dates = conteneur
          .read(filActiviteProvider('e1'))
          .value!
          .lignes
          .map((l) => l.creeLe)
          .toList();

      for (var i = 1; i < dates.length; i++) {
        expect(
          dates[i].isAfter(dates[i - 1]),
          isFalse,
          reason: 'le registre doit descendre du plus récent au plus ancien',
        );
      }
    });

    test(
      'deux remontées simultanées ne rendent pas la même page deux fois',
      () async {
        // Le défilement déclenche plusieurs fois de suite.
        final api = _ApiDouble(_lignes(45));
        final conteneur = _conteneur(api);

        await conteneur.read(filActiviteProvider('e1').future);
        final notifier = conteneur.read(filActiviteProvider('e1').notifier);

        await Future.wait([
          notifier.chargerPlusAncien(),
          notifier.chargerPlusAncien(),
        ]);

        final identifiants = conteneur
            .read(filActiviteProvider('e1'))
            .value!
            .lignes
            .map((l) => l.id)
            .toList();

        expect(identifiants.toSet(), hasLength(identifiants.length));
      },
    );

    test('remonter au bout arrête de demander', () async {
      final api = _ApiDouble(_lignes(45));
      final conteneur = _conteneur(api);

      await conteneur.read(filActiviteProvider('e1').future);
      final notifier = conteneur.read(filActiviteProvider('e1').notifier);

      await notifier.chargerPlusAncien();
      final appelsApresLeBout = api.appels;
      await notifier.chargerPlusAncien();

      expect(api.appels, appelsApresLeBout);
    });

    test('un rafraîchissement raté laisse le registre lisible', () async {
      // Déclenché par le temps réel, donc sans que personne l'ait demandé : lever ici
      // effacerait un registre parfaitement lisible pour un incident réseau passager.
      final api = _ApiDouble(_lignes(10));
      final conteneur = _conteneur(api);

      await conteneur.read(filActiviteProvider('e1').future);

      api.echoue = true;
      await conteneur.read(filActiviteProvider('e1').notifier).rafraichir();

      final etat = conteneur.read(filActiviteProvider('e1'));
      expect(etat.hasValue, isTrue);
      expect(etat.value!.lignes, hasLength(10));
    });
  });
}
