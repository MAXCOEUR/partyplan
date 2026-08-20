import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/invitation.dart' as modeles;
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/invitation_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Écran d’invitation', () {
    testWidgets('affiche le lien, le code court et le QR', (tester) async {
      await _monter(tester);

      expect(find.text('https://partyplan.test/join/JETON-SECRET'), findsOneWidget);
      expect(find.text('PLAN-K7M2X9'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('le QR est sur fond blanc, quel que soit le thème', (tester) async {
      await _monter(tester);

      // Sans fond blanc imposé, le code n'est pas lisible par un téléphone en thème
      // sombre : le thème ne fournit pas ce fond.
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, Colors.white);
    });

    testWidgets('EF-INV-05 : la régénération avertit avant d’agir', (tester) async {
      await _monter(tester);

      await tester.tap(find.byKey(const ValueKey('regenerer')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Le lien et le code actuels cesseront de fonctionner.'),
        findsOneWidget,
      );
    });

    testWidgets('EF-INV-06 : l’état fermé est visible', (tester) async {
      await _monter(tester, adhesionsOuvertes: false);

      expect(find.text('Les nouvelles arrivées sont fermées.'), findsOneWidget);
    });
  });
}

Future<void> _monter(WidgetTester tester, {bool adhesionsOuvertes = true}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      evenementProvider.overrideWith((ref, id) async => resume()),
      invitationProvider.overrideWith(
        (ref, id) async => modeles.Invitation(
          jeton: 'JETON-SECRET',
          codeCourt: 'PLAN-K7M2X9',
          lien: 'https://partyplan.test/join/JETON-SECRET',
          adhesionsOuvertes: adhesionsOuvertes,
        ),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const InvitationPage(evenementId: 'e1'),
    conteneur: conteneur,
  );
}
