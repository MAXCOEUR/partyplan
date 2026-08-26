import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/features/activite/phrase_activite.dart';
import 'package:partyplan/l10n/generated/pp_localisations.dart';

import '../aide/monter_ecran.dart';

Activite _ligne(String categorie, [Map<String, dynamic>? donnees]) => Activite(
  id: 'a1',
  auteur: 'Camille',
  categorie: categorie,
  donnees: donnees,
  creeLe: DateTime(2026, 8, 26, 18, 30),
);

/// Monte un contexte localisé et rend la fonction de composition.
Future<PpL10n> _localisations(WidgetTester tester) async {
  final conteneur = ProviderContainer();
  addTearDown(conteneur.dispose);

  late PpL10n l10n;
  await monterEcran(
    tester,
    Builder(
      builder: (context) {
        l10n = PpL10n.of(context);
        return const SizedBox.shrink();
      },
    ),
    conteneur: conteneur,
  );

  return l10n;
}

void main() {
  group('phraseActivite', () {
    testWidgets('compose une phrase pour chacune des treize catégories', (
      tester,
    ) async {
      final l10n = await _localisations(tester);

      final cas = <Activite>[
        _ligne('member.joined'),
        _ligne('member.status_changed', {'de': 'Unknown', 'vers': 'Going'}),
        _ligne('item.created', {'libelle': 'Glaçons'}),
        _ligne('item.deleted', {'libelle': 'Glaçons'}),
        _ligne('item.claimed', {'libelle': 'Glaçons'}),
        _ligne('item.unclaimed', {'libelle': 'Glaçons'}),
        _ligne('item.purchased', {'libelle': 'Glaçons', 'montant': 4.5}),
        _ligne('expense.created', {'libelle': 'Courses', 'montant': 62.4}),
        _ligne('expense.updated', {
          'libelle': 'Courses',
          'ancienMontant': 62.4,
          'montant': 58.1,
        }),
        _ligne('expense.deleted', {'libelle': 'Courses', 'montant': 62.4}),
        _ligne('settlement.marked', {
          'de': 'Alex',
          'vers': 'Camille',
          'montant': 12.3,
        }),
        _ligne('settlement.cancelled', {
          'de': 'Alex',
          'vers': 'Camille',
          'montant': 12.3,
        }),
        _ligne('event.date_or_place_changed', {
          'champs': ['date'],
        }),
      ];

      expect(cas, hasLength(13));

      for (final activite in cas) {
        final phrase = phraseActivite(l10n, activite);
        expect(
          phrase.trim(),
          isNotEmpty,
          reason: 'aucune phrase pour ${activite.categorie}',
        );
      }
    });

    testWidgets('nomme l’article dans la phrase', (tester) async {
      final l10n = await _localisations(tester);

      expect(
        phraseActivite(l10n, _ligne('item.claimed', {'libelle': 'Glaçons'})),
        contains('Glaçons'),
      );
    });

    testWidgets('donne les deux montants d’une dépense modifiée', (
      tester,
    ) async {
      // « Combien c'était avant » est la question posée en cas de désaccord.
      final l10n = await _localisations(tester);

      final phrase = phraseActivite(
        l10n,
        _ligne('expense.updated', {
          'libelle': 'Courses',
          'ancienMontant': 62.4,
          'montant': 58.1,
        }),
      );

      expect(phrase, contains('62,40'));
      expect(phrase, contains('58,10'));
    });

    testWidgets('nomme le débiteur et le créancier d’un remboursement', (
      tester,
    ) async {
      // L'auteur peut être un troisième membre : le nommer ne suffirait pas.
      final l10n = await _localisations(tester);

      final phrase = phraseActivite(
        l10n,
        _ligne('settlement.marked', {
          'de': 'Alex',
          'vers': 'Camille',
          'montant': 12.3,
        }),
      );

      expect(phrase, contains('Alex'));
      expect(phrase, contains('Camille'));
      expect(phrase, contains('12,30'));
    });

    testWidgets('distingue la date, le lieu et les deux', (tester) async {
      final l10n = await _localisations(tester);

      final date = phraseActivite(
        l10n,
        _ligne('event.date_or_place_changed', {
          'champs': ['date'],
        }),
      );
      final lieu = phraseActivite(
        l10n,
        _ligne('event.date_or_place_changed', {
          'champs': ['lieu'],
        }),
      );
      final deux = phraseActivite(
        l10n,
        _ligne('event.date_or_place_changed', {
          'champs': ['date', 'lieu'],
        }),
      );

      expect(date, isNot(equals(lieu)));
      expect(deux, isNot(equals(date)));
      expect(deux, isNot(equals(lieu)));
    });

    testWidgets('dégrade sans planter sur une catégorie inconnue', (
      tester,
    ) async {
      // Le fil est en ajout seul : une ligne écrite par une version future du serveur
      // restera en base pour toujours. L'écran doit la traverser, pas s'y arrêter.
      final l10n = await _localisations(tester);

      expect(
        phraseActivite(l10n, _ligne('quelque.chose.de.neuf')).trim(),
        isNotEmpty,
      );
    });

    testWidgets('dégrade sans planter sur un payload incomplet', (
      tester,
    ) async {
      final l10n = await _localisations(tester);

      expect(phraseActivite(l10n, _ligne('item.created')).trim(), isNotEmpty);
      expect(
        phraseActivite(l10n, _ligne('expense.created', {'libelle': 'Courses'}))
            .trim(),
        isNotEmpty,
      );
    });
  });
}
