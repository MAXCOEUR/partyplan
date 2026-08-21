import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partyplan/design/components/pp_date_pastille.dart';

void main() {
  setUp(() => initializeDateFormatting('fr_FR'));

  group('PpDatePastille', () {
    testWidgets('montre le jour en grand et le mois abrégé', (tester) async {
      // « C'est quand ? » est la première question devant une liste de soirées : la
      // réponse doit se lire sans lire.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PpDatePastille(date: DateTime(2026, 9, 12, 20, 30)),
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('sept.'), findsOneWidget);
    });

    testWidgets('annonce l’heure quand elle est connue', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PpDatePastille(
              date: DateTime(2026, 9, 12, 20, 30),
              avecHeure: true,
            ),
          ),
        ),
      );

      expect(find.text('20:30'), findsOneWidget);
    });

    testWidgets('une date non fixée le dit, sans case vide', (tester) async {
      // Un événement peut naître avant sa date : on choisit le jour ensemble ensuite.
      // Laisser la pastille vide donnerait l'impression d'une donnée manquante plutôt
      // que d'une décision à prendre.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PpDatePastille(date: null))),
      );

      expect(find.text('À définir'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    });

    testWidgets('reste lisible sur une soirée passée', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PpDatePastille(
              date: DateTime(2025, 12, 31, 22),
              estompee: true,
            ),
          ),
        ),
      );

      expect(find.text('31'), findsOneWidget);
      expect(find.text('déc.'), findsOneWidget);
    });
  });
}
