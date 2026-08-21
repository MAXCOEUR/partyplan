import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_rail.dart';
import 'package:partyplan/design/tokens.dart';

void main() {
  group('PpRail', () {
    testWidgets('sur un écran large, le contenu reste dans un rail centré', (
      tester,
    ) async {
      // Une liste étirée sur 1280 px place le libellé d'un article à gauche et son
      // bouton d'attribution à un mètre de là : l'œil ne fait plus le lien, et la
      // même application paraît bâclée sur navigateur.
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PpRail(
              child: SizedBox(
                width: double.infinity,
                height: 10,
                key: Key('contenu'),
              ),
            ),
          ),
        ),
      );

      final largeur = tester.getSize(find.byKey(const Key('contenu'))).width;

      expect(largeur, PpBreakpoints.railContenu);
    });

    testWidgets('sur un téléphone, le contenu occupe toute la largeur', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PpRail(
              child: SizedBox(
                width: double.infinity,
                height: 10,
                key: Key('contenu'),
              ),
            ),
          ),
        ),
      );

      final largeur = tester.getSize(find.byKey(const Key('contenu'))).width;

      // 1080 / 3 = 360 points logiques.
      expect(largeur, 360);
    });

    test('le seuil de bascule sépare le téléphone de la tablette', () {
      // Sous ce seuil, une navigation latérale mangerait la moitié de l'écran.
      expect(PpBreakpoints.large, greaterThan(600));
      expect(PpBreakpoints.railContenu, lessThan(PpBreakpoints.large));
    });
  });
}
