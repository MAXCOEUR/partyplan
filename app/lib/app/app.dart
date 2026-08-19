import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../l10n/pp_strings.dart';
import 'router.dart';

/// Racine de l'application.
class PartyPlanApp extends ConsumerWidget {
  const PartyPlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: PpStrings.nomProduit,
    debugShowCheckedModeBanner: false,
    theme: PpTheme.clair(),
    darkTheme: PpTheme.sombre(),
    routerConfig: ref.watch(routeurProvider),
  );
}
