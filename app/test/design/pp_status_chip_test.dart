import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_status_chip.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/design/theme.dart';

/// Les délégués de localisation sont indispensables depuis que les libellés du
/// composant viennent des chaînes traduites et non plus du code (NF-I18N-01).
Widget _sous(Widget enfant) => MaterialApp(
  localizationsDelegates: PartyPlanApp.delegues,
  supportedLocales: PartyPlanApp.languesPrisesEnCharge,
  locale: const Locale('fr'),
  theme: PpTheme.clair(),
  home: Scaffold(body: Center(child: enfant)),
);

void main() {
  group('PpStatusChip', () {
    testWidgets('les cinq statuts ont chacun un libellé distinct', (
      tester,
    ) async {
      final libelles = <String>{};

      for (final presence in PpPresence.values) {
        await tester.pumpWidget(_sous(PpStatusChip(presence: presence)));
        libelles.add(tester.widget<Text>(find.byType(Text)).data!);
      }

      // « Absent » et « Sans réponse » partagent une couleur mais jamais un libellé.
      expect(libelles.length, PpPresence.values.length);
    });

    testWidgets('l’heure annoncée complète le statut', (tester) async {
      await tester.pumpWidget(
        _sous(
          const PpStatusChip(presence: PpPresence.arriveTard, heure: '21h30'),
        ),
      );

      expect(find.text('Arrive plus tard · 21h30'), findsOneWidget);
    });

    testWidgets('« peut-être » se distingue visuellement des présents', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sous(const PpStatusChip(presence: PpPresence.present)),
      );
      final present = tester.widget<Text>(find.byType(Text)).style!.color;

      await tester.pumpWidget(
        _sous(const PpStatusChip(presence: PpPresence.peutEtre)),
      );
      final peutEtre = tester.widget<Text>(find.byType(Text)).style!.color;

      // RG-PRES-03 : « peut-être » n'entre pas dans la répartition des dépenses,
      // l'organisateur doit donc le repérer immédiatement.
      expect(peutEtre, isNot(present));
    });

    testWidgets('« arrive plus tard » porte la couleur des présents', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sous(const PpStatusChip(presence: PpPresence.present)),
      );
      final present = tester.widget<Text>(find.byType(Text)).style!.color;

      await tester.pumpWidget(
        _sous(const PpStatusChip(presence: PpPresence.arriveTard)),
      );
      final tard = tester.widget<Text>(find.byType(Text)).style!.color;

      // RG-PRES-02
      expect(tard, present);
    });
  });
}
