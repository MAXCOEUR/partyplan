import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../l10n/pp_strings.dart';
import 'router.dart';

/// Racine de l'application.
class PartyPlanApp extends ConsumerStatefulWidget {
  const PartyPlanApp({super.key});

  @override
  ConsumerState<PartyPlanApp> createState() => _PartyPlanAppState();
}

class _PartyPlanAppState extends ConsumerState<PartyPlanApp> {
  late final _routeur = creerRouteur();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: PpStrings.nomProduit,
    debugShowCheckedModeBanner: false,
    theme: PpTheme.clair(),
    darkTheme: PpTheme.sombre(),
    routerConfig: _routeur,
  );
}
