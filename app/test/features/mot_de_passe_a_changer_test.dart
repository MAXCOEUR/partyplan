import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/auth/mot_de_passe_a_changer_page.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Changement de mot de passe imposé (RG-ADM-10)', () {
    testWidgets('un compte tenu de changer son mot de passe y est conduit', (
      tester,
    ) async {
      // Sans cette redirection, le compte administrateur amorcé atterrit sur
      // l'accueil, où le serveur refuse chaque lecture en 403 : l'écran reste vide
      // et rien n'indique quoi faire.
      final conteneur = _conteneurConnecte(motDePasseAChanger: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MotDePasseAChangerPage), findsOneWidget);
      expect(find.byType(AccueilPage), findsNothing);
    });

    testWidgets('un compte ordinaire garde accès à l’accueil', (tester) async {
      final conteneur = _conteneurConnecte(motDePasseAChanger: false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: conteneur,
          child: const PartyPlanApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccueilPage), findsOneWidget);
      expect(find.byType(MotDePasseAChangerPage), findsNothing);
    });

    test('la route du changement imposé n’est pas publique', () {
      // Elle exige une session : l'exposer publiquement offrirait un formulaire de
      // changement de mot de passe à un appelant anonyme.
      expect(PpRoutes.publiques, isNot(contains(PpRoutes.motDePasseAChanger)));
    });

    test('le refus du serveur lève le drapeau, une fois pour toutes', () async {
      // C'est le point de sortie réseau qui reconnaît le refus : si chaque écran
      // devait le faire, le premier à l'oublier laisserait un écran vide.
      var signale = false;
      final client = _clientRefusant(() => signale = true);

      await expectLater(
        client.get<void>('/events', analyser: (_) {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.exigeChangementMotDePasse,
            'exigeChangementMotDePasse',
            isTrue,
          ),
        ),
      );

      expect(signale, isTrue);
    });

    test('un autre refus en 403 ne lève pas le drapeau', () async {
      // Un 403 ordinaire ne doit pas détourner vers un formulaire de mot de passe.
      var signale = false;
      final client = _clientRefusant(
        () => signale = true,
        code: 'event.join_closed',
      );

      await expectLater(
        client.get<void>('/events', analyser: (_) {}),
        throwsA(isA<ApiException>()),
      );

      expect(signale, isFalse);
    });
  });
}

ProviderContainer _conteneurConnecte({required bool motDePasseAChanger}) {
  final conteneur = ProviderContainer(
    overrides: [
      // Un jeton présent suffit à placer la session en « connecté » : c'est ainsi que
      // `SessionCourante` détermine l'état au démarrage.
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(
          jetonAcces: 'jeton-test',
          jetonRafraichissement: 'rafraichissement-test',
        ),
      ),
      // L'accueil lance sinon un véritable appel réseau, dont le délai d'attente
      // survit à la fin du test.
      mesEvenementsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(conteneur.dispose);

  if (motDePasseAChanger) {
    conteneur.read(motDePasseAChangerProvider.notifier).exiger();
  }

  return conteneur;
}

/// Client dont toute requête reçoit un refus 403 portant [code].
ApiClient _clientRefusant(void Function() signal, {String? code}) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 403,
          data: {
            'title': 'Change ton mot de passe avant de continuer.',
            'status': 403,
            'code': code ?? 'auth.must_change_password',
          },
        ),
      ),
    ),
  );

  return ApiClient(
    SessionStoreDouble(jetonAcces: 'jeton-test'),
    dio: dio,
    auChangementImpose: signal,
  );
}
