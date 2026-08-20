import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partyplan/app/app.dart';

/// Monte un écran isolé, avec ses délégués de localisation et ses providers substitués.
///
/// Le conteneur est passé plutôt qu'une liste de substitutions : `Override` n'est pas
/// exporté par l'API publique de Riverpod 3, et un littéral de liste passé à
/// `ProviderContainer` en infère le type sans avoir à le nommer.
///
/// `initializeDateFormatting` est appelé ici parce que `main.dart` ne l'est pas dans un
/// test : sans lui, tout `DateFormat` en « fr_FR » lève à la première mise en forme.
Future<void> monterEcran(
  WidgetTester tester,
  Widget ecran, {
  required ProviderContainer conteneur,
}) async {
  await initializeDateFormatting('fr_FR');

  // Surface haute et étroite : un téléphone en hauteur, mais assez long pour qu'une
  // liste paresseuse construise toutes ses sections. Sans cela, un test qui vérifie
  // qu'une section apparaît selon le rôle vérifierait en réalité la position de
  // défilement. Les contraintes de taille tactile se testent à part.
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp(
        localizationsDelegates: PartyPlanApp.delegues,
        supportedLocales: PartyPlanApp.languesPrisesEnCharge,
        locale: const Locale('fr'),
        home: ecran,
      ),
    ),
  );

  await tester.pumpAndSettle();
}
