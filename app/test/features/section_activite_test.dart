import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/core/network/activite_api.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/sections/section_activite.dart';

import '../aide/monter_ecran.dart';
import '../doubles/activite_api_double.dart';

Activite _ligne(String id, String libelle) => Activite(
  id: id,
  auteur: 'Camille',
  categorie: 'item.created',
  donnees: {'libelle': libelle},
  creeLe: DateTime(2026, 8, 26, 18, 30),
);

Future<void> _monter(
  WidgetTester tester,
  List<Activite> lignes, {
  bool encore = false,
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      activiteApiProvider.overrideWithValue(
        ActiviteApiDouble(lignes: lignes, encore: encore),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const Scaffold(body: SectionActivite(evenementId: 'e1')),
    conteneur: conteneur,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Section activité du tableau de bord', () {
    testWidgets('affiche au plus trois lignes', (tester) async {
      // Le tableau de bord est un résumé : au-delà de trois, la section prend la place
      // des autres blocs et l'écran complet existe pour ça.
      await _monter(tester, [
        _ligne('a1', 'Glaçons'),
        _ligne('a2', 'Chips'),
        _ligne('a3', 'Bière'),
        _ligne('a4', 'Pain'),
        _ligne('a5', 'Nappe'),
      ]);

      expect(find.textContaining('Glaçons'), findsOneWidget);
      expect(find.textContaining('Chips'), findsOneWidget);
      expect(find.textContaining('Bière'), findsOneWidget);
      expect(find.textContaining('Pain'), findsNothing);
      expect(find.textContaining('Nappe'), findsNothing);
    });

    testWidgets('propose d’ouvrir le fil complet', (tester) async {
      await _monter(tester, [_ligne('a1', 'Glaçons')]);

      expect(find.text('Tout voir'), findsOneWidget);
    });

    testWidgets('reste muette quand le fil est vide', (tester) async {
      // Un bloc « Activité » vide sur le tableau de bord d'une soirée neuve occuperait
      // la place utile sans rien dire. La section disparaît entièrement, plutôt que
      // d'afficher un état vide de plus.
      await _monter(tester, const []);

      expect(find.text('Activité'), findsNothing);
      expect(find.text('Tout voir'), findsNothing);
    });

    testWidgets('reste muette tant que le fil n’est pas chargé', (
      tester,
    ) async {
      // Un squelette de plus sur un tableau de bord qui en porte déjà ferait clignoter
      // l'écran à chaque ouverture.
      final conteneur = ProviderContainer(
        overrides: [
          // Une lecture qui ne rend jamais : la section doit rester muette tant que le
          // fil n'est pas chargé.
          activiteApiProvider.overrideWithValue(const _ApiQuiNeRendJamais()),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: SectionActivite(evenementId: 'e1')),
        conteneur: conteneur,
      );
      await tester.pump();

      expect(find.text('Activité'), findsNothing);
    });

    testWidgets('reste muette quand le fil est en erreur', (tester) async {
      // L'activité est un complément : son échec ne doit pas parasiter un tableau de
      // bord dont le reste s'affiche correctement.
      final conteneur = ProviderContainer(
        overrides: [
          activiteApiProvider.overrideWithValue(const _ApiQuiEchoue()),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const Scaffold(body: SectionActivite(evenementId: 'e1')),
        conteneur: conteneur,
      );

      expect(find.text('Activité'), findsNothing);
    });
  });
}

/// Lecture qui ne rend jamais : éprouve l'état de chargement.
class _ApiQuiNeRendJamais implements ActiviteApi {
  const _ApiQuiNeRendJamais();

  @override
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) => Completer<PageActivite>().future;
}

/// Lecture qui échoue : éprouve l'effacement de la section.
class _ApiQuiEchoue implements ActiviteApi {
  const _ApiQuiEchoue();

  @override
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) async => throw Exception('réseau');
}
