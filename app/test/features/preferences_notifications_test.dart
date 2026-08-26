import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/avis.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/profil/preferences_notifications_page.dart';

import '../aide/monter_ecran.dart';

const _categories = [
  'invitation.answer',
  'event.changed',
  'invitation.pending',
  'shopping.unclaimed',
  'event.starting_soon',
  'balance.due',
  'activity',
];

Future<void> _monter(
  WidgetTester tester,
  List<PreferenceAvis> preferences,
) async {
  final conteneur = ProviderContainer(
    overrides: [
      preferencesAvisProvider.overrideWith((ref) async => preferences),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const PreferencesNotificationsPage(),
    conteneur: conteneur,
  );
}

void main() {
  group('Préférences de notification', () {
    testWidgets('propose un interrupteur par catégorie', (tester) async {
      await _monter(tester, [
        for (final categorie in _categories)
          PreferenceAvis(categorie: categorie, poussee: true, courriel: true),
      ]);

      expect(find.byType(SwitchListTile), findsNWidgets(_categories.length));
    });

    testWidgets('nomme les catégories en clair, jamais par leur identifiant', (
      tester,
    ) async {
      // Une personne coupe ce qui l'importune, elle ne configure pas un système.
      await _monter(tester, [
        for (final categorie in _categories)
          PreferenceAvis(categorie: categorie, poussee: true, courriel: true),
      ]);

      expect(find.text('Réponses aux invitations'), findsOneWidget);
      expect(find.text('Montants à rembourser'), findsOneWidget);
      expect(find.text('invitation.answer'), findsNothing);
      expect(find.text('balance.due'), findsNothing);
    });

    testWidgets('reflète une catégorie déjà coupée', (tester) async {
      await _monter(tester, const [
        PreferenceAvis(categorie: 'activity', poussee: false, courriel: false),
      ]);

      final interrupteur = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );

      expect(interrupteur.value, isFalse);
    });

    testWidgets('annonce la plage de silence plutôt que de la cacher', (
      tester,
    ) async {
      // Savoir que rien n'arrive la nuit évite de tout couper par précaution.
      await _monter(tester, const [
        PreferenceAvis(categorie: 'activity', poussee: true, courriel: true),
      ]);

      expect(find.textContaining('22 h et 8 h'), findsOneWidget);
    });

    testWidgets('une catégorie inconnue reste réglable', (tester) async {
      // Écrite par une version plus récente du serveur : mieux vaut une ligne au nom
      // technique qu'un réglage qu'on ne peut plus couper.
      await _monter(tester, const [
        PreferenceAvis(
          categorie: 'quelque.chose',
          poussee: true,
          courriel: true,
        ),
      ]);

      expect(find.text('quelque.chose'), findsOneWidget);
    });
  });
}
