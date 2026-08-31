import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/design/components/pp_bouton_google.dart';
import 'package:partyplan/design/components/pp_logo_google.dart';

import '../aide/monter_ecran.dart';

/// Le bouton de connexion Google.
///
/// Ce qui compte ici n'est pas qu'il soit joli, mais qu'il soit *reconnaissable* : le
/// logo de la marque, son libellé, sa forme. Un bouton de connexion tierce se reconnaît
/// avant d'être lu.
void main() {
  group('Bouton Google', () {
    testWidgets('porte le logo et le libellé de la marque', (tester) async {
      await _monter(tester, onPressed: () {});

      expect(find.byType(PpLogoGoogle), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);
    });

    testWidgets('appuyer déclenche la connexion', (tester) async {
      var appuis = 0;
      await _monter(tester, onPressed: () => appuis++);

      await tester.tap(find.byKey(const Key('connexion-google')));
      await tester.pumpAndSettle();

      expect(appuis, 1);
    });

    testWidgets('désactivé, il ne déclenche rien', (tester) async {
      await _monter(tester, onPressed: null);

      await tester.tap(
        find.byKey(const Key('connexion-google')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Rien à vérifier d'autre qu'une absence d'exception : le rappel est nul, et le
      // bouton reste affiché plutôt que de disparaître pendant la connexion.
      expect(find.text('Continuer avec Google'), findsOneWidget);
    });

    testWidgets('garde les couleurs de la marque en thème sombre', (
      tester,
    ) async {
      // La palette du bouton ne se dérive pas du ColorScheme : ce sont des constantes
      // de Google. Un bouton repeint aux couleurs de PartyPlan serait méconnaissable.
      await _monter(tester, onPressed: () {}, sombre: true);

      final materiau = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PpBoutonGoogle),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(materiau.color, const Color(0xFF131314));
    });

    testWidgets('tient dans une largeur étroite sans déborder', (tester) async {
      await _monter(tester, onPressed: () {}, largeur: 180);

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _monter(
  WidgetTester tester, {
  required VoidCallback? onPressed,
  bool sombre = false,
  double? largeur,
}) async {
  final conteneur = ProviderContainer();
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    Theme(
      data: ThemeData(brightness: sombre ? Brightness.dark : Brightness.light),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: largeur,
            child: PpBoutonGoogle(onPressed: onPressed),
          ),
        ),
      ),
    ),
    conteneur: conteneur,
  );
}
