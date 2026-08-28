import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/network/api_exception.dart';
import 'package:partyplan/core/network/evenements_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/creation_evenement_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

/// Refuse la création comme le fait le serveur au-delà du quota (RG-PRM-01).
class _ApiQuotaAtteint implements EvenementsApi {
  static const message =
      'Tu organises déjà 3 soirées à venir, le maximum de la formule gratuite. '
      'Attends la fin de l’une d’elles, quitte-la ou supprime-la — ou passe à la '
      'formule payante.';

  @override
  Future<ResumeEvenement> creer({
    required String nom,
    required DateTime debut,
    DateTime? fin,
    String? adresse,
    String? description,
    required String cleIdempotence,
  }) async => throw ApiException(
    statusCode: 403,
    title: message,
    code: 'plan.event_quota_reached',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('Assistant de création', () {
    testWidgets('démarre à l’étape 1 sur la question du nom', (tester) async {
      await _monter(tester);

      expect(find.text('Ça s’appelle comment ?'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('refuse de passer à l’étape 2 sans nom', (tester) async {
      await _monter(tester);

      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      expect(find.text('Donne un nom à ton événement.'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('le retour à l’étape précédente ne perd pas la saisie', (
      tester,
    ) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      // Appui direct sur le premier segment de la barre de progression.
      await tester.tap(find.byKey(const ValueKey('etape-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Crémaillère'), findsOneWidget);
    });

    testWidgets('« Créer » est actif dès l’étape 2', (tester) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      // Nom et date suffisent à l'API : imposer l'étape 3 ferait de la description un
      // champ obligatoire de fait.
      expect(find.text('Créer l’événement'), findsOneWidget);
    });

    testWidgets('la barre de progression ne mène pas au-delà sans nom', (
      tester,
    ) async {
      await _monter(tester);

      // La clé porte sur l'InkWell lui-même : un segment inaccessible n'a pas de
      // rappel d'appui, il n'est pas seulement grisé.
      final segment = tester.widget<InkWell>(
        find.byKey(const ValueKey('etape-2')),
      );

      expect(segment.onTap, isNull);
    });

    testWidgets('NF-A11Y-02 : chaque segment mesure au moins 44 points', (
      tester,
    ) async {
      await _monter(tester);

      for (var i = 1; i <= 3; i++) {
        final taille = tester.getSize(find.byKey(ValueKey('etape-$i')));
        expect(taille.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('un refus du serveur est affiché tel quel, sans être réécrit', (
      tester,
    ) async {
      // Le quota nomme sa cause et ses sorties. Le remplacer par « l'événement n'a
      // pas pu être créé » laisse l'organisateur sans rien à faire de l'information.
      await _monter(tester, api: _ApiQuotaAtteint());

      await tester.enterText(find.byType(TextFormField).first, 'Soirée de trop');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer l’événement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('le maximum de la formule gratuite'), findsOneWidget);
      expect(find.text('L’événement n’a pas pu être créé.'), findsNothing);
    });

    testWidgets('NF-A11Y-03 : chaque segment porte un libellé sémantique', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _monter(tester);

      expect(find.bySemanticsLabel('Aller à l’étape 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Aller à l’étape 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Aller à l’étape 3'), findsOneWidget);

      handle.dispose();
    });
  });
}

Future<void> _monter(WidgetTester tester, {EvenementsApi? api}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      if (api != null) evenementsApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const CreationEvenementPage(),
    conteneur: conteneur,
  );
}
