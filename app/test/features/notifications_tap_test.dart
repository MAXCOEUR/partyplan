import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/avis.dart';
import 'package:partyplan/core/network/avis_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/notifications/notifications_page.dart';

import '../aide/monter_ecran.dart';

/// Doublure d'API qui peut échouer, pour éprouver le comportement hors ligne.
class _AvisApiDouble implements AvisApi {
  _AvisApiDouble({this.echoue = false});

  bool echoue;
  final marques = <String>[];
  int toutMarque = 0;

  @override
  Future<PageAvis> lire({String? avant, int limite = 30}) async =>
      PageAvis(avis: [_avis()], encore: false, nonLus: 1);

  @override
  Future<void> marquerLu(String id) async {
    if (echoue) {
      throw Exception('réseau');
    }

    marques.add(id);
  }

  @override
  Future<void> toutMarquerLu() async {
    if (echoue) {
      throw Exception('réseau');
    }

    toutMarque++;
  }

  @override
  Future<List<PreferenceAvis>> preferences() async => const [];

  @override
  Future<void> definirPreference(PreferenceAvis preference) async {}

  @override
  Future<bool> sourdine(String evenementId) async => false;

  @override
  Future<void> definirSourdine(
    String evenementId, {
    required bool enSourdine,
  }) async {}

  @override
  Future<List<PreferenceDeSoiree>> preferencesDeSoiree(
    String evenementId,
  ) async => const [];

  @override
  Future<void> definirPreferenceDeSoiree(
    String evenementId,
    String categorie,
    bool? actif,
  ) async {}
}

Avis _avis() => Avis(
  id: 'a1',
  categorie: 'invitation.answer',
  titre: 'Une réponse est arrivée',
  corps: 'Camille a répondu oui.',
  recuLe: DateTime(2026, 8, 26, 18, 30),
  lu: false,
  evenementId: 'e1',
  lienProfond: '/events/e1',
);

Future<List<String>> _taper(WidgetTester tester, _AvisApiDouble api) async {
  final ouverts = <String>[];

  final conteneur = ProviderContainer(
    overrides: [avisApiProvider.overrideWithValue(api)],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    NotificationsPage(ouvrir: ouverts.add),
    conteneur: conteneur,
  );

  await tester.tap(find.text('Une réponse est arrivée'));
  await tester.pumpAndSettle();

  return ouverts;
}

void main() {
  group('Ouverture d’une notification', () {
    testWidgets('taper ouvre le lien profond et marque lu', (tester) async {
      final api = _AvisApiDouble();

      final ouverts = await _taper(tester, api);

      expect(ouverts, ['/events/e1']);
      expect(api.marques, ['a1']);
    });

    testWidgets('hors ligne, taper ouvre quand même le lien', (tester) async {
      // Le défaut trouvé en revue : marquerLu relançait la DioException, qui
      // interrompait la closure avant la navigation. Dans le métro, taper une
      // notification ne faisait strictement rien — ni ouverture, ni message, et la
      // pastille restait pleine. Marquer lu est un confort ; ouvrir est le geste.
      final api = _AvisApiDouble(echoue: true);

      final ouverts = await _taper(tester, api);

      expect(ouverts, ['/events/e1']);
    });

    testWidgets('hors ligne, l’échec du marquage ne remonte pas en exception', (
      tester,
    ) async {
      final api = _AvisApiDouble(echoue: true);

      await _taper(tester, api);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tout marquer lu ne lève pas hors ligne', (tester) async {
      final api = _AvisApiDouble(echoue: true);
      final conteneur = ProviderContainer(
        overrides: [avisApiProvider.overrideWithValue(api)],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        NotificationsPage(ouvrir: (_) {}),
        conteneur: conteneur,
      );

      await tester.tap(find.text('Tout marquer comme lu'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
