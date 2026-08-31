import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/storage/session_store.dart';

/// L'appareil se réinscrit à chaque lancement.
///
/// Le jeton n'était envoyé qu'une fois, au moment où la permission est accordée, et
/// ensuite seulement lors de ses rotations. Un premier envoi manqué — réseau coupé,
/// session expirée, API momentanément indisponible — n'était donc jamais rattrapé :
/// l'appareil restait inconnu du serveur, et la personne n'avait plus jamais aucune
/// notification, sans le moindre message. L'inscription est idempotente côté serveur,
/// la répéter ne coûte rien.
void main() {
  group('Réinscription au lancement', () {
    testWidgets('le jeton repart à chaque démarrage', (tester) async {
      final service = _ServiceDouble();
      await _monter(tester, service);

      expect(service.reinscriptions, 1);
    });

    testWidgets('les autres écoutes restent posées', (tester) async {
      // Elles sont posées une seule fois, dans initState : rappelées à chaque
      // reconstruction, elles empileraient les abonnements et une notification tapée
      // provoquerait autant de navigations.
      final service = _ServiceDouble();
      await _monter(tester, service);

      expect(service.rafraichissements, 1);
      expect(service.ouvertures, 1);
      expect(service.premiersPlans, 1);
    });

    testWidgets('un échec de réinscription ne casse pas le démarrage', (
      tester,
    ) async {
      // Rien de ce qui touche aux notifications ne doit empêcher l'application de
      // s'afficher.
      final service = _ServiceDouble(echoue: true);
      await _monter(tester, service);

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _monter(WidgetTester tester, ServiceNotifications service) async {
  final conteneur = ProviderContainer(
    overrides: [
      serviceNotificationsProvider.overrideWithValue(service),
      sessionStoreProvider.overrideWithValue(_StockageVide()),
      mesEvenementsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(conteneur.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _ServiceDouble implements ServiceNotifications {
  _ServiceDouble({this.echoue = false});

  final bool echoue;

  int reinscriptions = 0;
  int rafraichissements = 0;
  int ouvertures = 0;
  int premiersPlans = 0;

  @override
  Future<EtatNotifications> etatCourant() async => EtatNotifications.accorde;

  @override
  Future<void> demanderEtEnregistrer() async {}

  @override
  Future<void> reinscrireAppareil() async {
    reinscriptions++;
    if (echoue) {
      throw Exception('API injoignable');
    }
  }

  @override
  Future<void> retirerAppareilCourant() async {}

  @override
  Future<void> ecouterRafraichissements() async => rafraichissements++;

  @override
  Future<void> ecouterOuvertures(
    void Function(String destination) aller,
  ) async => ouvertures++;

  @override
  Future<void> ecouterPremierPlan(
    void Function(NotificationRecue recue) montrer,
  ) async => premiersPlans++;
}

class _StockageVide implements SessionStore {
  @override
  Future<String?> lireJetonAcces() async => null;

  @override
  Future<String?> lireJetonRafraichissement() async => null;

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
