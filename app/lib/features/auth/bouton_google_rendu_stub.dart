import 'package:flutter/widgets.dart';

/// Bouton rendu par le SDK Google — indisponible hors du Web.
///
/// Les plateformes mobiles utilisent le parcours programmatique et le bouton de
/// l'application. Ce talon existe pour que l'import conditionnel se résolve à la
/// compilation sans embarquer le greffon web dans l'APK.
Widget? boutonRenduGoogle() => null;
