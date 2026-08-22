import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';

void main() {
  // Sans cet appel, `DateFormat` avec la locale « fr_FR » lève à la première mise en
  // forme : les symboles de date ne sont pas chargés par défaut.
  initializeDateFormatting('fr_FR');
  Intl.defaultLocale = 'fr_FR';
  usePathUrlStrategy();

  runApp(const ProviderScope(child: PartyPlanApp()));
}
