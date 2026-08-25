import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../design/theme.dart';
import '../l10n/generated/pp_localisations.dart';
import '../l10n/marque.dart';
import 'router.dart';

/// Racine de l'application.
class PartyPlanApp extends ConsumerStatefulWidget {
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
  ConsumerState<PartyPlanApp> createState() => _PartyPlanAppState();
}

class _PartyPlanAppState extends ConsumerState<PartyPlanApp> {
  @override
  void initState() {
    super.initState();

    // Posée une seule fois, et non dans build : rappelé à chaque reconstruction, il
    // empilerait les abonnements, et une notification tapée provoquerait autant de
    // navigations.
    //
    // Les Future ne sont pas attendues : l'application ne doit pas retarder son premier
    // affichage pour une écoute de notifications.
    final service = ref.read(serviceNotificationsProvider);
    final routeur = ref.read(routeurProvider);

    // ignore: discarded_futures
    service.ecouterRafraichissements();
    // ignore: discarded_futures
    service.ecouterOuvertures(routeur.go);
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: PpMarque.nom,
    debugShowCheckedModeBanner: false,
    // Le français est la seule langue livrée ; les délégués sont posés dès maintenant
    // pour que les libellés de Material soient traduits eux aussi.
    localizationsDelegates: PartyPlanApp.delegues,
    supportedLocales: PartyPlanApp.languesPrisesEnCharge,
    locale: const Locale('fr'),
    theme: PpTheme.clair(),
    darkTheme: PpTheme.sombre(),
    routerConfig: ref.watch(routeurProvider),
  );
}
