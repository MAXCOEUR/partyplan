import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_card.dart';

void main() {
  group('PpCard', () {
    testWidgets('une carte sans action n’est pas annoncée comme un bouton', (
      tester,
    ) async {
      // Une carte décorative enveloppée dans un InkWell inerte fusionne ses
      // descendants en un nœud unique : un lecteur d'écran annonce alors le titre, la
      // quantité et le libellé du bouton d'action comme un seul bouton, et les
      // commandes qu'elle contient deviennent inatteignables au clavier.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PpCard(
              child: Column(
                children: [Text('Bières'), Text('À prendre')],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('À prendre')),
        isNot(matchesSemantics(isButton: true)),
      );

      // Les deux textes restent deux nœuds distincts, non fusionnés.
      expect(find.text('Bières'), findsOneWidget);
      expect(find.text('À prendre'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('une carte actionnable reste un bouton', (tester) async {
      var appuis = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PpCard(
              onTap: () => appuis++,
              child: const Text('Soirée test'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Soirée test'));
      await tester.pumpAndSettle();

      expect(appuis, 1);
    });
  });
}
