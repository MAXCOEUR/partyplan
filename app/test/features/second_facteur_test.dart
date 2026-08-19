import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/models/profil.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/auth/second_facteur_page.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Écran de second facteur', () {
    testWidgets('accepte aussi un code de secours', (tester) async {
      await _monter(tester);

      // Refuser un code de secours ici enfermerait dehors quiconque a perdu son
      // téléphone : l'aide doit le dire explicitement.
      expect(find.textContaining('XXXX-XXXX'), findsOneWidget);
    });

    testWidgets('refuse une soumission vide sans appeler le réseau', (
      tester,
    ) async {
      await _monter(tester);

      await tester.ensureVisible(find.text('Vérifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vérifier'));
      await tester.pumpAndSettle();

      expect(
        find.text('Saisis le code affiché par ton application.'),
        findsOneWidget,
      );
    });

    testWidgets('explique la dérive d’horloge', (tester) async {
      await _monter(tester);

      // Première cause d'échec d'un code valide : l'horloge du téléphone.
      expect(find.textContaining('heure de ton téléphone'), findsOneWidget);
    });
  });

  group('Routage du second facteur', () {
    test('la seconde étape est publique : aucune session n’existe encore', () {
      expect(PpRoutes.publiques, contains(PpRoutes.secondFacteur));
    });

    test('le réglage du second facteur n’est pas public', () {
      expect(
        PpRoutes.publiques,
        isNot(contains(PpRoutes.secondFacteurReglage)),
      );
    });
  });

  group('Modèle de profil', () {
    test('lit l’état du second facteur et du mot de passe à changer', () {
      final profil = Profil.depuisJson({
        'id': '0198f000-0000-7000-8000-000000000000',
        'email': 'admin@partyplan.local',
        'emailVerified': true,
        'displayName': 'Administrateur',
        'locale': 'fr-FR',
        'timezone': 'Europe/Paris',
        'platformRole': 'PlatformAdmin',
        'hasPassword': true,
        'totpEnabled': true,
        'mustChangePassword': true,
        'createdAt': '2026-08-19T10:00:00Z',
      });

      expect(profil.doubleAuthentification, isTrue);
      expect(profil.motDePasseAChanger, isTrue);
      expect(profil.estAdministrateur, isTrue);
      expect(profil.estPersonnelPlateforme, isTrue);
    });

    test('un secret d’enrôlement est découpé en groupes de quatre', () {
      final enrolement = EnrolementTotp.depuisJson({
        'secret': 'ABCDEFGHIJKLMNOP',
        'otpAuthUri': 'otpauth://totp/PartyPlan:x?secret=ABCDEFGHIJKLMNOP',
      });

      // Le secret se recopie à la main quand le QR code n'est pas scannable.
      expect(enrolement.secretLisible, 'ABCD EFGH IJKL MNOP');
    });

    test('un résultat de connexion distingue le défi de la session', () {
      final defi = ResultatConnexion.depuisJson({
        'requiresSecondFactor': true,
        'challengeToken': 'jeton-de-defi',
        'accessToken': null,
      });

      expect(defi.secondFacteurRequis, isTrue);
      expect(defi.jetonDefi, 'jeton-de-defi');
    });
  });
}

Future<void> _monter(WidgetTester tester) async {
  final conteneur = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(SessionStoreDouble())],
  );
  addTearDown(conteneur.dispose);

  final routeur = conteneur.read(routeurProvider);
  routeur.go(PpRoutes.secondFacteur, extra: 'jeton-de-defi-de-test');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(routerConfig: routeur),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(SecondFacteurPage), findsOneWidget);
}
