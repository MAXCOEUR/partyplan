import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

/// Jeton d'accès portant un rôle, de la forme émise par l'API.
String _jetonAvecRole(String role) {
  String segment(Map<String, Object?> contenu) =>
      base64Url.encode(utf8.encode(jsonEncode(contenu))).replaceAll('=', '');

  return '${segment({'alg': 'RS256'})}'
      '.${segment({'pp:platform_role': role})}.signature';
}

Future<void> _monter(WidgetTester tester, {required String role}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: _jetonAvecRole(role)),
      ),
      mesEvenementsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
}

void main() {
  group('Accès à l’administration depuis l’accueil', () {
    testWidgets('un administrateur trouve l’entrée sans passer par son profil', (
      tester,
    ) async {
      // Gérer les comptes est le travail quotidien d'un administrateur : l'entrée
      // enterrée dans « Mon profil » se cherche à chaque fois.
      await _monter(tester, role: 'PlatformAdmin');

      expect(find.byTooltip('Administration'), findsOneWidget);
    });

    testWidgets('le personnel de support y accède aussi', (tester) async {
      await _monter(tester, role: 'Support');

      expect(find.byTooltip('Administration'), findsOneWidget);
    });

    testWidgets('un compte ordinaire ne voit rien', (tester) async {
      // RG-ADM-01 : un rôle plateforme ne lit pas le contenu d'un événement, et un
      // compte ordinaire n'a rien à voir du back-office — pas même son existence.
      await _monter(tester, role: 'User');

      expect(find.byTooltip('Administration'), findsNothing);
    });
  });
}
