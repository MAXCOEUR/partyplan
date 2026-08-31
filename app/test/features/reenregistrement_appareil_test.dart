import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/core/storage/session_store.dart';

/// L'appareil s'inscrit dès qu'une session existe, et à chaque fois qu'elle revient.
///
/// Le jeton n'était envoyé qu'au lancement de l'application. Sur une installation
/// neuve, l'ordre des choses est pourtant : lancement sans session, écran de connexion,
/// puis connexion. Le jeton partait donc avant toute session, l'API le refusait, et rien
/// ne rattrapait avant le lancement suivant — une personne qui installe, se connecte et
/// utilise l'application n'avait aucune notification de toute sa première session.
///
/// L'inscription est idempotente côté serveur : la répéter ne coûte rien.
void main() {
  group('Inscription de l’appareil', () {
    testWidgets('rien ne part tant que personne n’est connecté', (
      tester,
    ) async {
      // L'appel exige une session : le tenter sans elle produit un refus silencieux,
      // qui était exactement la panne.
      final service = _ServiceDouble();
      await _monter(tester, service, EtatSession.anonyme);

      expect(service.inscriptions, 0);
    });

    testWidgets('une session déjà ouverte inscrit au lancement', (tester) async {
      final service = _ServiceDouble();
      await _monter(tester, service, EtatSession.connecte);

      expect(service.inscriptions, 1);
    });

    testWidgets('se connecter inscrit l’appareil, sans attendre un relancement', (
      tester,
    ) async {
      // Le cas de toute première installation, et donc de chaque nouvelle personne.
      final service = _ServiceDouble();
      final session = await _monter(tester, service, EtatSession.anonyme);

      expect(service.inscriptions, 0, reason: 'rien avant la connexion');

      session.devenirConnecte();
      await tester.pumpAndSettle();

      expect(service.inscriptions, 1);
    });

    testWidgets('les écoutes de notification restent posées une seule fois', (
      tester,
    ) async {
      // Posées dans initState : rappelées à chaque reconstruction, elles empileraient
      // les abonnements et une notification tapée provoquerait autant de navigations.
      final service = _ServiceDouble();
      final session = await _monter(tester, service, EtatSession.anonyme);

      session.devenirConnecte();
      await tester.pumpAndSettle();

      expect(service.rafraichissements, 1);
      expect(service.ouvertures, 1);
      expect(service.premiersPlans, 1);
    });

    testWidgets('un échec d’inscription ne casse pas le démarrage', (
      tester,
    ) async {
      // Rien de ce qui touche aux notifications ne doit empêcher l'application de
      // s'afficher.
      final service = _ServiceDouble(echoue: true);
      await _monter(tester, service, EtatSession.connecte);

      expect(tester.takeException(), isNull);
    });
  });
}

Future<_SessionDeTest> _monter(
  WidgetTester tester,
  ServiceNotifications service,
  EtatSession etat,
) async {
  final session = _SessionDeTest(etat);

  final conteneur = ProviderContainer(
    overrides: [
      serviceNotificationsProvider.overrideWithValue(service),
      sessionProvider.overrideWith(() => session),
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

  return session;
}

/// Session pilotée par le test, pour observer la transition qui compte.
class _SessionDeTest extends SessionCourante {
  _SessionDeTest(this._initial);

  final EtatSession _initial;

  @override
  Future<EtatSession> build() async => _initial;

  void devenirConnecte() => state = const AsyncData(EtatSession.connecte);
}

class _ServiceDouble implements ServiceNotifications {
  _ServiceDouble({this.echoue = false});

  final bool echoue;

  int inscriptions = 0;
  int rafraichissements = 0;
  int ouvertures = 0;
  int premiersPlans = 0;

  @override
  Future<EtatNotifications> etatCourant() async => EtatNotifications.accorde;

  @override
  Future<void> demanderEtEnregistrer() async {}

  @override
  Future<void> reinscrireAppareil() async {
    inscriptions++;
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
