import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_avatar.dart';
import 'package:partyplan/design/components/pp_claim_chip.dart';
import 'package:partyplan/design/theme.dart';
import 'package:partyplan/design/tokens.dart';

Widget _sous(Widget enfant) => MaterialApp(
  theme: PpTheme.clair(),
  home: Scaffold(body: Center(child: enfant)),
);

void main() {
  group('PpClaimChip', () {
    testWidgets('libre : contour, libellé d’appel à l’action, aucun avatar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sous(const PpClaimChip(libelleLibre: 'À prendre')),
      );

      expect(find.text('À prendre'), findsOneWidget);
      expect(find.byType(PpAvatar), findsNothing);
    });

    testWidgets('pris : aplat, nom et visage de la personne', (tester) async {
      await tester.pumpWidget(
        _sous(
          const PpClaimChip(
            libelleLibre: 'À prendre',
            nomAttributaire: 'Lucas',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lucas'), findsOneWidget);
      expect(find.byType(PpAvatar), findsOneWidget);
      expect(find.text('À prendre'), findsNothing);
    });

    testWidgets('respecte la cible tactile minimale', (tester) async {
      await tester.pumpWidget(
        _sous(const PpClaimChip(libelleLibre: 'À prendre')),
      );

      final taille = tester.getSize(find.byType(PpClaimChip));

      // NF-A11Y-02
      expect(taille.height, greaterThanOrEqualTo(PpA11y.cibleMinimale));
    });

    testWidgets('une écriture en cours neutralise l’appui', (tester) async {
      var appuis = 0;

      await tester.pumpWidget(
        _sous(
          PpClaimChip(
            libelleLibre: 'À prendre',
            enCours: true,
            onPressed: () => appuis++,
          ),
        ),
      );

      await tester.tap(find.byType(PpClaimChip));
      await tester.pump();

      // RG-UI-03 : une écriture optimiste en attente ne doit pas pouvoir être relancée.
      expect(appuis, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('déclenche l’appui lorsqu’elle est libre', (tester) async {
      var appuis = 0;

      await tester.pumpWidget(
        _sous(
          PpClaimChip(libelleLibre: 'À prendre', onPressed: () => appuis++),
        ),
      );

      await tester.tap(find.byType(PpClaimChip));
      await tester.pump();

      expect(appuis, 1);
    });
  });
}
