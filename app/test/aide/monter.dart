import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partyplan/app/app.dart';

/// Monte un widget isolé avec les délégués de localisation de l'application.
///
/// Les écrans complets se montent par `PartyPlanApp` ; cette aide ne sert qu'aux
/// composants du système de design, qui n'ont pas besoin du routeur.
///
/// `initializeDateFormatting` est appelé ici parce que `main.dart` ne l'est pas dans un
/// test : sans lui, tout `DateFormat` en « fr_FR » lève à la première mise en forme.
Future<void> monterWidget(WidgetTester tester, Widget enfant) async {
  await initializeDateFormatting('fr_FR');

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: PartyPlanApp.delegues,
      supportedLocales: PartyPlanApp.languesPrisesEnCharge,
      locale: const Locale('fr'),
      home: Scaffold(body: enfant),
    ),
  );
}
