import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_form.dart';

void main() {
  group('PpPrimaryButton', () {
    testWidgets('un libellé long ne fait pas déborder le bouton', (
      tester,
    ) async {
      // Un bouton dont le texte dépasse est un défaut du composant, pas de l'écran qui
      // l'emploie : « Enregistrer la correction » doit tenir sur un téléphone étroit
      // comme sur une tablette.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PpPrimaryButton(
                label: 'Enregistrer la correction du montant payé',
                icone: Icons.check_rounded,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Aucune exception de mise en page : Flutter les remonte au test.
      expect(tester.takeException(), isNull);
      expect(find.byType(PpPrimaryButton), findsOneWidget);
    });

    testWidgets('le libellé reste lisible en largeur normale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PpPrimaryButton(label: 'Enregistrer', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });
}
