import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_barre_app.dart';
import 'package:partyplan/design/components/pp_rail.dart';
import 'package:partyplan/design/tokens.dart';

void main() {
  group('PpBarreApp', () {
    testWidgets('aligne son titre sur le rail de contenu', (tester) async {
      // Un titre collé au bord gauche quand le contenu commence au tiers de l'écran
      // donne l'impression de deux mises en page superposées.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PpBarreApp(titre: Text('PartyPlan')),
            body: PpRail(child: SizedBox(width: double.infinity, height: 10)),
          ),
        ),
      );

      final bordTitre = tester.getTopLeft(find.text('PartyPlan')).dx;
      // Le rail de 600 points est centré dans 1280 : son bord gauche tombe à 340, et
      // la marge intérieure place le contenu à 356. C'est sur ce bord — celui des
      // cartes — que le titre doit tomber, pas sur celui du rail nu.
      final bordContenu =
          (1280 - PpBreakpoints.railContenu) / 2 + PpSpacing.lg;

      expect(bordTitre, closeTo(bordContenu, 1));
    });

    testWidgets('sur téléphone, le titre reste au bord', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: PpBarreApp(titre: Text('PartyPlan'))),
        ),
      );

      expect(tester.getTopLeft(find.text('PartyPlan')).dx, lessThan(24));
    });

    testWidgets('les actions restent atteignables', (tester) async {
      var appuis = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PpBarreApp(
              titre: const Text('PartyPlan'),
              actions: [
                IconButton(
                  onPressed: () => appuis++,
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(appuis, 1);
    });
  });
}
