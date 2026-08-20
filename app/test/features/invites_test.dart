import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/evenement/invites_page.dart';
import 'package:partyplan/features/evenement/presence_vers_pastille.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

void main() {
  test('les six statuts ont une pastille', () {
    for (final statut in StatutPresence.values) {
      expect(() => versPastille(statut), returnsNormally);
    }
  });

  group('Écran des invités', () {
    testWidgets('EF-PRES-05 : synthèse avec les peut-être comptés à part', (
      tester,
    ) async {
      await _monter(tester, [
        membre(id: 'a', nom: 'Léa'),
        // RG-PRES-02 : « arrive plus tard » compte comme présent.
        membre(id: 'b', nom: 'Tom', statut: StatutPresence.enRetard),
        membre(id: 'c', nom: 'Zoé', statut: StatutPresence.peutEtre),
        membre(id: 'd', nom: 'Max', statut: StatutPresence.inconnu),
      ]);

      expect(find.text('2 présents sur 4 invités'), findsOneWidget);
      expect(find.text('1 peut-être'), findsOneWidget);
    });

    testWidgets('EF-PRES-03 : on ne règle que ses propres accompagnants', (
      tester,
    ) async {
      await _monter(tester, [
        membre(id: 'moi', nom: 'Moi', cestMoi: true),
        membre(id: 'lea', nom: 'Léa'),
      ]);

      expect(find.byKey(const ValueKey('accompagnant-plus')), findsOneWidget);
    });

    testWidgets('EF-PRES-06 : les accompagnants sont plafonnés à dix', (
      tester,
    ) async {
      await _monter(tester, [
        membre(id: 'moi', nom: 'Moi', accompagnants: 10, cestMoi: true),
      ]);

      final bouton = tester.widget<IconButton>(
        find.byKey(const ValueKey('accompagnant-plus')),
      );

      expect(bouton.onPressed, isNull);
      expect(
        find.text('Au-delà de dix accompagnants, il s’agit d’un autre événement.'),
        findsOneWidget,
      );
    });

    testWidgets('l’exclusion est réservée à qui peut gérer', (tester) async {
      await _monter(tester, [
        membre(id: 'moi', nom: 'Moi', cestMoi: true),
        membre(id: 'lea', nom: 'Léa'),
      ]);

      expect(find.byKey(const ValueKey('exclure-lea')), findsNothing);
    });

    testWidgets('RG-ROLE-01 : le propriétaire ne peut pas être exclu', (
      tester,
    ) async {
      await _monter(tester, [
        membre(
          id: 'moi',
          nom: 'Moi',
          role: RoleMembre.administrateur,
          cestMoi: true,
        ),
        membre(id: 'chef', nom: 'Chef', role: RoleMembre.proprietaire),
        membre(id: 'lea', nom: 'Léa'),
      ]);

      expect(find.byKey(const ValueKey('exclure-chef')), findsNothing);
      expect(find.byKey(const ValueKey('exclure-lea')), findsOneWidget);
    });

    testWidgets('RG-ROLE-03 : la confirmation dit que les dépenses restent', (
      tester,
    ) async {
      await _monter(tester, [
        membre(
          id: 'moi',
          nom: 'Moi',
          role: RoleMembre.proprietaire,
          cestMoi: true,
        ),
        membre(id: 'lea', nom: 'Léa'),
      ]);

      await tester.tap(find.byKey(const ValueKey('exclure-lea')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ses dépenses et ses achats restent comptabilisés.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _monter(WidgetTester tester, List<Membre> membres) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      membresProvider.overrideWith((ref, id) async => membres),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(
    tester,
    const InvitesPage(evenementId: 'e1'),
    conteneur: conteneur,
  );
}
