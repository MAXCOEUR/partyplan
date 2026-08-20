import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../l10n/generated/pp_localisations.dart';
import '../l10n/marque.dart';
import 'router.dart';

/// Racine de l'application.
class PartyPlanApp extends ConsumerWidget {
  const PartyPlanApp({super.key});

  /// Délégués de localisation, partagés avec les tests pour qu'ils montent la même
  /// application que la production.
  ///
  /// Les libellés Cupertino sont inclus bien qu'aucun écran ne s'en serve : le framework
  /// vérifie qu'un délégué couvre chaque langue déclarée, et leur absence fait échouer
  /// tout test de widget. C'est aussi pourquoi `cupertino_icons` figure en dépendance.
  static const delegues = <LocalizationsDelegate<Object>>[
    PpL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const languesPrisesEnCharge = <Locale>[Locale('fr')];

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: PpMarque.nom,
    debugShowCheckedModeBanner: false,
    // Le français est la seule langue livrée ; les délégués sont posés dès maintenant
    // pour que les libellés de Material soient traduits eux aussi.
    localizationsDelegates: delegues,
    supportedLocales: languesPrisesEnCharge,
    locale: const Locale('fr'),
    theme: PpTheme.clair(),
    darkTheme: PpTheme.sombre(),
    routerConfig: ref.watch(routeurProvider),
  );
}
