import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/models/invitation.dart';
import 'package:partyplan/core/network/evenements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/rejoindre/apercu_invitation_page.dart';

import '../aide/fabriques.dart';
import '../doubles/session_store_double.dart';

void main() {
  group('Aperçu d’invitation', () {
    testWidgets('RG-INV-04 : ni liste nominative, ni dépenses', (tester) async {
      await _monterApercu(tester, donnees: apercu(participants: 8));

      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(find.text('8 participants'), findsOneWidget);
      // Le modèle ApercuInvitation ne porte aucun nom de membre : ce qui n'existe pas
      // ne peut pas fuiter.
      expect(find.text('Léa'), findsNothing);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets(
      'EF-INV-06 : l’aperçu reste lisible quand les arrivées sont fermées',
      (tester) async {
        final api = EvenementsApiInvitationDouble();

        await _monterApercu(
          tester,
          donnees: apercu(adhesionsOuvertes: false),
          connecte: true,
          api: api,
        );

        expect(find.text('Crémaillère chez Léa'), findsOneWidget);
        expect(
          find.text('L’organisateur a fermé les nouvelles arrivées.'),
          findsOneWidget,
        );
        expect(api.jetons, isEmpty);
        expect(api.codes, isEmpty);
      },
    );

    testWidgets('un anonyme choisit connexion ou création de compte', (
      tester,
    ) async {
      final api = EvenementsApiInvitationDouble();

      await _monterApercu(tester, api: api);

      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Créer un compte'), findsOneWidget);
      expect(find.text('Comment tu t’appelles ?'), findsNothing);
      expect(find.text('Tu viens ?'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(api.jetons, isEmpty);
    });

    testWidgets('un compte rejoint automatiquement puis ouvre la soirée', (
      tester,
    ) async {
      final api = EvenementsApiInvitationDouble(eventId: 'e1');
      final montage = await _monterApercu(tester, connecte: true, api: api);

      await tester.pumpAndSettle();

      expect(api.jetons, ['JETON']);
      expect(montage.routeCourante, '/events/e1');
    });

    testWidgets('un code court rejoint automatiquement comme un jeton', (
      tester,
    ) async {
      final api = EvenementsApiInvitationDouble(eventId: 'e-code');
      final montage = await _monterApercu(
        tester,
        code: 'k7m-2x9',
        connecte: true,
        api: api,
      );

      await tester.pumpAndSettle();

      expect(api.codes, ['k7m-2x9']);
      expect(api.jetons, isEmpty);
      expect(montage.routeCourante, '/events/e-code');
    });

    testWidgets('un membre existant rejoue le POST pour obtenir l’événement', (
      tester,
    ) async {
      final api = EvenementsApiInvitationDouble(eventId: 'e-membre');
      final montage = await _monterApercu(
        tester,
        donnees: apercu(dejaMembre: true),
        connecte: true,
        api: api,
      );

      await tester.pumpAndSettle();

      expect(api.jetons, ['JETON']);
      expect(montage.routeCourante, '/events/e-membre');
    });

    testWidgets('une erreur affiche un retry qui ne relance qu’une fois', (
      tester,
    ) async {
      final api = EvenementsApiInvitationDouble(
        eventId: 'e-retry',
        erreursAvantSucces: 1,
      );
      final montage = await _monterApercu(tester, connecte: true, api: api);

      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de rejoindre cet événement.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(api.jetons, ['JETON']);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.jetons, ['JETON', 'JETON']);
      expect(montage.routeCourante, '/events/e-retry');
    });

    testWidgets('une reconstruction ne double pas le POST en cours', (
      tester,
    ) async {
      final reponse = Completer<String>();
      final api = EvenementsApiInvitationDouble(reponseBloquee: reponse);
      final montage = await _monterApercu(
        tester,
        connecte: true,
        api: api,
        attendreStabilisation: false,
      );

      await tester.pump();
      await tester.pump();
      expect(api.jetons, ['JETON']);

      montage.conteneur.invalidate(
        apercuInvitationProvider((jeton: 'JETON', code: null)),
      );
      await tester.pump();
      await tester.pump();

      expect(api.jetons, ['JETON']);

      reponse.complete('e1');
      await tester.pumpAndSettle();
    });
  });

  group('Code court', () {
    test('la saisie est tolérante', () {
      for (final saisie in [
        'PLAN-K7M2X9',
        'plan-k7m2x9',
        ' plan k7m 2x9 ',
        'K7M2X9',
        'k7m-2x9',
      ]) {
        expect(EvenementsApi.normaliserCode(saisie), 'K7M2X9', reason: saisie);
      }
    });
  });
}

class EvenementsApiInvitationDouble implements EvenementsApi {
  EvenementsApiInvitationDouble({
    this.eventId = 'e1',
    this.erreursAvantSucces = 0,
    this.reponseBloquee,
  });

  final String eventId;
  int erreursAvantSucces;
  final Completer<String>? reponseBloquee;
  final List<String> jetons = [];
  final List<String> codes = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #rejoindreParJeton) {
      jetons.add(invocation.namedArguments[#jeton]! as String);
      return _repondre();
    }
    if (invocation.memberName == #rejoindreParCode) {
      codes.add(invocation.namedArguments[#code]! as String);
      return _repondre();
    }

    throw UnimplementedError(invocation.memberName.toString());
  }

  Future<String> _repondre() async {
    if (erreursAvantSucces > 0) {
      erreursAvantSucces--;
      throw Exception('réseau indisponible');
    }
    final bloquee = reponseBloquee;
    return bloquee == null ? eventId : bloquee.future;
  }
}

class _MontageApercu {
  const _MontageApercu(this.conteneur, this.routeur);

  final ProviderContainer conteneur;
  final GoRouter routeur;

  String get routeCourante =>
      routeur.routerDelegate.currentConfiguration.uri.path;
}

Future<_MontageApercu> _monterApercu(
  WidgetTester tester, {
  ApercuInvitation? donnees,
  String? code,
  bool connecte = false,
  EvenementsApiInvitationDouble? api,
  bool attendreStabilisation = true,
}) async {
  await initializeDateFormatting('fr_FR');
  final apiEffectif = api ?? EvenementsApiInvitationDouble();
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(
          jetonAcces: connecte ? 'jeton-compte' : null,
          jetonRafraichissement: connecte ? 'rafraichissement-compte' : null,
        ),
      ),
      evenementsApiProvider.overrideWithValue(apiEffectif),
      apercuInvitationProvider.overrideWith(
        (ref, cle) async => donnees ?? apercu(),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  final routeur = GoRouter(
    initialLocation: code == null ? '/join/JETON' : '/rejoindre/$code',
    routes: [
      GoRoute(
        path: '/join/:token',
        builder: (_, state) =>
            ApercuInvitationPage(jeton: state.pathParameters['token']),
      ),
      GoRoute(
        path: '/rejoindre/:code',
        builder: (_, state) =>
            ApercuInvitationPage(code: state.pathParameters['code']),
      ),
      GoRoute(path: '/connexion', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/inscription', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) =>
            Text('Événement ${state.pathParameters['eventId']}'),
      ),
    ],
  );
  addTearDown(routeur.dispose);

  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(
        localizationsDelegates: PartyPlanApp.delegues,
        supportedLocales: PartyPlanApp.languesPrisesEnCharge,
        locale: const Locale('fr'),
        routerConfig: routeur,
      ),
    ),
  );
  if (attendreStabilisation) {
    await tester.pumpAndSettle();
  }

  return _MontageApercu(conteneur, routeur);
}
