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
      // Présenter un refus d'autorisation comme une panne réseau envoie
      // l'administrateur vérifier un wifi qui marche, et son bouton « Réessayer » ne
      // pourra jamais aboutir. Le message doit donc nommer la cause.
      //
      // Depuis l'ADR 0007, cette cause n'est plus la double authentification : le
      // jeton porte déjà le rôle, sans quoi l'entrée serait cachée. Reste RG-ADM-10,
      // le mot de passe imposé au compte amorcé, et le rôle Support sur une action
      // réservée.
      await _monter(
        tester,
        const ApiException(statusCode: 403, title: 'Accès refusé.'),
      );

      // Le message renvoie vers le mot de passe imposé, plus vers un second facteur
      // qui n'existe plus — un écran qui envoie vers un réglage supprimé est un
      // cul-de-sac.
      expect(find.textContaining('mot de passe'), findsOneWidget);
      expect(find.textContaining('double authentification'), findsNothing);
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
