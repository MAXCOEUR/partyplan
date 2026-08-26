import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/auth/connexion_page.dart';
import 'package:partyplan/features/auth/inscription_page.dart';
import 'package:partyplan/features/rejoindre/apercu_invitation_page.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Écran de connexion', () {
    testWidgets('affiche les deux champs et le bouton', (tester) async {
      await _monter(tester);

      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('refuse une soumission vide sans appeler le réseau', (
      tester,
    ) async {
      await _monter(tester);

      await _appuyer(tester, find.text('Se connecter'));

      // La validation locale évite un aller-retour pour une faute évidente.
      expect(find.text('Indique ton adresse e-mail.'), findsOneWidget);
      expect(find.text('Indique ton mot de passe.'), findsOneWidget);
    });

    testWidgets('signale une adresse manifestement invalide', (tester) async {
      await _monter(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'pas-une-adresse',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Trombone-Nuage-42x',
      );
      await _appuyer(tester, find.text('Se connecter'));

      expect(
        find.text('Cette adresse ne ressemble pas à une adresse e-mail.'),
        findsOneWidget,
      );
    });

    testWidgets('mène à l’inscription', (tester) async {
      await _monter(tester);

      // La surface de test est plus courte qu'un téléphone : le lien est sous la ligne
      // de flottaison et doit être amené à l'écran avant l'appui.
      await _appuyer(tester, find.text('Créer un compte'));

      expect(find.byType(InscriptionPage), findsOneWidget);
    });

    testWidgets('conserve le retour d’invitation vers l’inscription', (
      tester,
    ) async {
      await _monter(tester, route: '/connexion?retour=%2Fjoin%2FJETON');

      await _appuyer(tester, find.text('Créer un compte'));

      final page = tester.widget<InscriptionPage>(find.byType(InscriptionPage));
      expect(page.retour, '/join/JETON');
    });

    testWidgets('revient à l’aperçu après une connexion réussie', (
      tester,
    ) async {
      await _monter(tester, route: '/connexion?retour=%2Fjoin%2FJETON');

      await tester.enterText(
        find.byType(TextFormField).first,
        'max@partyplan.local',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Trombone-Nuage-42x',
      );
      await _appuyer(tester, find.text('Se connecter'));

      expect(find.byType(ApercuInvitationPage), findsOneWidget);
    });

    testWidgets('ignore un retour externe après une connexion réussie', (
      tester,
    ) async {
      await _monter(
        tester,
        route: '/connexion?retour=https%3A%2F%2Fevil.test%2Fjoin%2FJETON',
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'max@partyplan.local',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Trombone-Nuage-42x',
      );
      await _appuyer(tester, find.text('Se connecter'));

      expect(find.byType(ApercuInvitationPage), findsNothing);
      expect(find.byType(AccueilPage), findsOneWidget);
    });

    testWidgets('ne déborde pas sur un écran étroit', (tester) async {
      // 320 points de large : le plus petit écran encore en service. Un débordement ici
      // masquerait le lien d'inscription, c'est-à-dire le parcours d'acquisition.
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _monter(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Créer un compte'), findsOneWidget);
    });
  });

  group('Écran d’inscription', () {
    testWidgets('énonce la règle de mot de passe avant la faute', (
      tester,
    ) async {
      await _monter(tester, route: PpRoutes.inscription);

      // La règle est visible d'emblée : la découvrir en message d'erreur est une
      // mauvaise façon de la communiquer. Les quatre exigences sont donc annoncées,
      // pas seulement la longueur.
      expect(find.textContaining('une majuscule'), findsOneWidget);
      expect(find.textContaining('un caractère spécial'), findsOneWidget);
    });

    testWidgets('refuse deux saisies différentes sans appeler le serveur', (
      tester,
    ) async {
      // Une faute de frappe sur un champ masqué ne se voit pas. Sans cette seconde
      // saisie, la personne se retrouverait enfermée dehors avec un mot de passe
      // qu'elle croit connaître, et aucun message ne le lui dirait.
      await _monter(tester, route: PpRoutes.inscription);

      await tester.enterText(find.byType(TextFormField).at(0), 'Maxence');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'max@partyplan.local',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Trombone-Nuage-42x',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Trombone-Nuage-42y',
      );
      await _appuyer(tester, find.text('Créer mon compte'));

      expect(
        find.textContaining('ne correspondent pas'),
        findsOneWidget,
        reason: 'la faute doit être signalée sur place',
      );
    });

    testWidgets('refuse un mot de passe trop court en local', (tester) async {
      await _monter(tester, route: PpRoutes.inscription);

      await tester.enterText(find.byType(TextFormField).at(0), 'Maxence');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'max@partyplan.local',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'court');
      await _appuyer(tester, find.text('Créer mon compte'));

      expect(find.textContaining('caractère(s)'), findsOneWidget);
    });

    testWidgets('revient à l’aperçu après une inscription réussie', (
      tester,
    ) async {
      await _monter(
        tester,
        route: '/inscription?retour=%2Frejoindre%2FPLAN-K7M2X9',
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Maxence');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'max@partyplan.local',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Trombone-Nuage-42x',
      );
      // La confirmation est obligatoire depuis le 25/08/2026 : sans elle, le
      // formulaire ne se valide pas et l'inscription n'est jamais envoyée.
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Trombone-Nuage-42x',
      );
      await _appuyer(tester, find.text('Créer mon compte'));

      expect(find.byType(ApercuInvitationPage), findsOneWidget);
    });
  });
}

/// Amène un élément à l'écran puis appuie dessus.
///
/// La surface de test par défaut est plus courte qu'un téléphone : sans défilement,
/// l'appui porte hors du viewport et n'a aucun effet, ce qui produit un échec trompeur.
Future<void> _appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

Future<void> _monter(
  WidgetTester tester, {
  String route = PpRoutes.connexion,
}) async {
  final stockage = SessionStoreDouble();
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..interceptors.add(_ServeurAuth());
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(stockage),
      apiClientProvider.overrideWithValue(ApiClient(stockage, dio: dio)),
      apercuInvitationProvider.overrideWith((ref, cle) async => _apercu),
    ],
  );
  addTearDown(conteneur.dispose);

  final routeur = conteneur.read(routeurProvider);
  routeur.go(route);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: const PartyPlanApp(),
    ),
  );
  await tester.pumpAndSettle();

  if (route.startsWith(PpRoutes.connexion)) {
    expect(find.byType(ConnexionPage), findsOneWidget);
  }
}

final _apercu = ApercuInvitation(
  nom: 'Crémaillère',
  debut: DateTime.utc(2026, 9, 12, 20),
  fin: null,
  adresse: null,
  description: null,
  nombreParticipants: 3,
  adhesionsOuvertes: true,
  dejaMembre: false,
);

/// Simule uniquement les réponses HTTP d'authentification : le routeur et la session
/// de l'application restent les vrais objets du parcours.
class _ServeurAuth extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final estAuth =
        options.path == '/auth/login' || options.path == '/auth/register';
    if (!estAuth) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'accessToken': 'jeton-test',
          'refreshToken': 'rafraichissement-test',
        },
      ),
    );
  }
}
