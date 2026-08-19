import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_money.dart';
import 'package:partyplan/design/theme.dart';
import 'package:partyplan/design/tokens.dart';

Widget _sous(Widget enfant) => MaterialApp(
  theme: PpTheme.clair(),
  home: Scaffold(body: Center(child: enfant)),
);

void main() {
  group('PpMoney', () {
    testWidgets('sépare les euros et les centimes', (tester) async {
      await tester.pumpWidget(_sous(const PpMoney(184.37)));

      final texte = tester.widget<Text>(find.byType(Text));
      final rendu = texte.textSpan!.toPlainText();

      expect(rendu, '184,37${PpMoney.espaceInsecable}€');
    });

    testWidgets('arrondit au centime sans perdre de valeur', (tester) async {
      await tester.pumpWidget(_sous(const PpMoney(61.335)));

      final rendu = tester
          .widget<Text>(find.byType(Text))
          .textSpan!
          .toPlainText();

      expect(rendu, '61,34${PpMoney.espaceInsecable}€');
    });

    testWidgets('affiche deux décimales même sur un montant rond', (
      tester,
    ) async {
      await tester.pumpWidget(_sous(const PpMoney(50)));

      expect(
        tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText(),
        '50,00${PpMoney.espaceInsecable}€',
      );
    });

    testWidgets('un créditeur est vert, un débiteur est rose', (tester) async {
      // En thème clair, les variantes accessibles sont attendues : les couleurs vives
      // de la charte échouent au seuil WCAG AA (NF-A11Y-01).
      await tester.pumpWidget(
        _sous(
          const Column(
            children: [
              PpMoney(21.40, sense: PpMoneySense.crediteur),
              PpMoney(12.70, sense: PpMoneySense.debiteur),
            ],
          ),
        ),
      );

      final textes = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(
        (textes[0].textSpan! as TextSpan).children!.first.style!.color,
        PpColors.vertTexte,
      );
      expect(
        (textes[1].textSpan! as TextSpan).children!.first.style!.color,
        PpColors.roseTexte,
      );
    });

    testWidgets('le signe n’apparaît que sur demande', (tester) async {
      await tester.pumpWidget(
        _sous(const PpMoney(-38.66, afficherSigne: true)),
      );

      expect(
        tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText(),
        '−38,66${PpMoney.espaceInsecable}€',
      );
    });

    testWidgets('utilise des chiffres à largeur fixe', (tester) async {
      // Sans cette caractéristique, une colonne de montants ne s'aligne pas.
      await tester.pumpWidget(_sous(const PpMoney(1234.50)));

      final premier =
          (tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan)
                  .children!
                  .first
              as TextSpan;

      expect(
        premier.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('annonce une phrase au lecteur d’écran', (tester) async {
      await tester.pumpWidget(
        _sous(const PpMoney(18.40, sense: PpMoneySense.debiteur)),
      );

      expect(find.bySemanticsLabel('Vous devez 18 euros 40'), findsOneWidget);
    });

    testWidgets('en thème sombre, les couleurs de charte sont conservées', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PpTheme.sombre(),
          home: const Scaffold(
            body: PpMoney(21.40, sense: PpMoneySense.crediteur),
          ),
        ),
      );

      final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;

      expect(span.children!.first.style!.color, PpColors.vert);
    });
  });
}
