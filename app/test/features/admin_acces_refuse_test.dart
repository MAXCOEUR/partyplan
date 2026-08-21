import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/admin/admin_comptes_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

Future<void> _monter(WidgetTester tester, ApiException refus) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: 'jeton'),
      ),
      comptesProvider.overrideWith((ref) async => throw refus),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const AdminComptesPage(), conteneur: conteneur);
}

void main() {
  group('Accès refusé au back-office', () {
    testWidgets('un refus d’autorisation dit ce qui manque', (tester) async {
      // RG-ADM-04 : tout rôle plateforme exige la double authentification. Présenter
      // ce refus comme une panne réseau envoie l'administrateur vérifier son wifi,
      // et son bouton « Réessayer » ne pourra jamais aboutir.
      await _monter(
        tester,
        const ApiException(statusCode: 403, title: 'Accès refusé.'),
      );

      expect(find.textContaining('double authentification'), findsOneWidget);
      expect(find.textContaining('Vérifie ta connexion'), findsNothing);
    });

    testWidgets('une vraie panne réseau garde son message', (tester) async {
      await _monter(
        tester,
        const ApiException(statusCode: 0, title: 'Réseau injoignable.'),
      );

      expect(find.textContaining('Vérifie ta connexion'), findsOneWidget);
    });
  });
}
