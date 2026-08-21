import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/network/evenements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/storage/session_store.dart';

/// Client d'API qui compte ses appels et répond avec un délai réaliste.
class _ApiEspion implements EvenementsApi {
  int appels = 0;

  @override
  Future<List<EvenementDeLaListe>> lister() async {
    appels++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Stockage dont les lectures ne répondent pas dans la même microtâche.
///
/// C'est le cas réel : le stockage sécurisé passe par un canal de plateforme. Un double
/// qui répond immédiatement masque tout défaut d'ordonnancement au démarrage.
class _StockageDiffere implements SessionStore {
  @override
  Future<String?> lireJetonAcces() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'jeton';
  }

  @override
  Future<String?> lireJetonRafraichissement() async => 'rafraichissement';

  @override
  Future<void> enregistrerSession({
    required String jetonAcces,
    required String jetonRafraichissement,
  }) async {}

  @override
  Future<void> effacerSession() async {}

  @override
  Future<void> toutEffacer() async {}
}

void main() {
  testWidgets('au démarrage, la liste n’est chargée qu’une fois', (
    tester,
  ) async {
    await initializeDateFormatting('fr_FR');

    final api = _ApiEspion();
    final conteneur = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_StockageDiffere()),
        evenementsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(conteneur.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: conteneur,
        child: const PartyPlanApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(
      api.appels,
      1,
      reason: 'la liste est chargée ${api.appels} fois au lieu d’une',
    );
  });
}
