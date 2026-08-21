import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_selecteur_emoji.dart';

Future<String?> _ouvrir(WidgetTester tester) async {
  String? choisi;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => choisi = await ouvrirSelecteurEmoji(context),
            child: const Text('Réagir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Réagir'));
  await tester.pumpAndSettle();

  return choisi;
}

void main() {
  group('PpSelecteurEmoji', () {
    testWidgets('propose d’abord les réactions les plus employées', (
      tester,
    ) async {
      // Une grille de mille emoji transforme un geste d'une seconde en fouille dans un
      // catalogue : les habituelles restent à portée immédiate.
      await _ouvrir(tester);

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('regroupe les emoji par familles', (tester) async {
      await _ouvrir(tester);

      expect(find.text('Fréquents'), findsOneWidget);
      expect(find.text('Visages'), findsOneWidget);
      expect(find.text('Fête'), findsOneWidget);
      expect(find.text('À boire et à manger'), findsOneWidget);
    });

    testWidgets('choisir un emoji le renvoie et referme la feuille', (
      tester,
    ) async {
      String? choisi;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    choisi = await ouvrirSelecteurEmoji(context),
                child: const Text('Réagir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Réagir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();

      expect(choisi, '🎉');
      expect(find.text('Fréquents'), findsNothing);
    });

    testWidgets('refermer sans choisir ne renvoie rien', (tester) async {
      String? choisi;
      var appele = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  choisi = await ouvrirSelecteurEmoji(context);
                  appele = true;
                },
                child: const Text('Réagir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Réagir'));
      await tester.pumpAndSettle();

      // Un appui à côté referme : c'est le geste attendu d'une feuille modale.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(appele, isTrue);
      expect(choisi, isNull);
    });

    test('aucun emoji n’est proposé deux fois', () {
      // Un doublon entre familles ferait douter d'avoir déjà réagi.
      final tous = [for (final famille in famillesEmoji) ...famille.emojis];

      expect(tous.length, tous.toSet().length);
    });

    test('chaque famille porte un nom et au moins un emoji', () {
      for (final famille in famillesEmoji) {
        expect(famille.nom, isNotEmpty);
        expect(famille.emojis, isNotEmpty);
      }
    });
  });
}
