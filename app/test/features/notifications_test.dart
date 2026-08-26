import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/dates.dart';
import 'package:partyplan/core/models/avis.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/notifications/notifications_page.dart';

import '../aide/monter_ecran.dart';

Avis _avis({
  String id = 'a1',
  String titre = 'Une réponse est arrivée',
  bool lu = false,
}) => Avis(
  id: id,
  categorie: 'invitation.answer',
  titre: titre,
  corps: 'Camille a répondu oui.',
  recuLe: DateTime(2026, 8, 26, 18, 30),
  lu: lu,
  evenementId: 'e1',
  lienProfond: '/events/e1',
);

Future<void> _monter(
  WidgetTester tester,
  List<Avis> avis, {
  int nonLus = 0,
}) async {
  final conteneur = ProviderContainer(
    overrides: [
      avisProvider.overrideWith(
        (ref) async => PageAvis(avis: avis, encore: false, nonLus: nonLus),
      ),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const NotificationsPage(), conteneur: conteneur);
}

void main() {
  group('Écran des notifications', () {
    testWidgets('liste les notifications reçues', (tester) async {
      await _monter(tester, [_avis()], nonLus: 1);

      expect(find.text('Une réponse est arrivée'), findsOneWidget);
      expect(find.text('Camille a répondu oui.'), findsOneWidget);
    });

    testWidgets('propose de tout marquer lu quand il reste des non-lues', (
      tester,
    ) async {
      await _monter(tester, [_avis()], nonLus: 1);

      expect(find.text('Tout marquer comme lu'), findsOneWidget);
    });

    testWidgets('ne propose rien à marquer quand tout est lu', (tester) async {
      // Un bouton sans effet est une invitation à douter d'avoir bien appuyé.
      await _monter(tester, [_avis(lu: true)]);

      expect(find.text('Tout marquer comme lu'), findsNothing);
    });

    testWidgets('affiche un état vide explicite', (tester) async {
      await _monter(tester, const []);

      expect(find.text('Aucune notification'), findsOneWidget);
    });

    testWidgets('annonce une erreur avec une reprise', (tester) async {
      final conteneur = ProviderContainer(
        overrides: [
          // L'état d'erreur est fourni tel quel : Riverpod 3 réessaie un provider en
          // échec, et son minuteur de reprise survivrait au démontage du widget.
          avisProvider.overrideWithValue(
            AsyncError<PageAvis>(Exception('réseau'), StackTrace.empty),
          ),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(
        tester,
        const NotificationsPage(),
        conteneur: conteneur,
      );

      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('ilYA', () {
    final maintenant = DateTime(2026, 8, 26, 18, 30);

    test('moins d’une minute se dit « à l’instant »', () {
      expect(
        ilYA(
          maintenant.subtract(const Duration(seconds: 30)),
          depuis: maintenant,
        ),
        'à l’instant',
      );
    });

    test('dans l’heure, la minute compte', () {
      expect(
        ilYA(
          maintenant.subtract(const Duration(minutes: 5)),
          depuis: maintenant,
        ),
        'il y a 5 min',
      );
    });

    test('dans la journée, l’heure suffit', () {
      expect(
        ilYA(maintenant.subtract(const Duration(hours: 3)), depuis: maintenant),
        'il y a 3 h',
      );
    });

    test('la veille se dit « hier »', () {
      expect(ilYA(DateTime(2026, 8, 25, 9), depuis: maintenant), 'hier');
    });

    test('au-delà d’une semaine, seule la date importe', () {
      // « il y a 1 437 minutes » serait exact et inutilisable.
      expect(ilYA(DateTime(2026, 7, 4, 20), depuis: maintenant), '04/07/2026');
    });
  });
}
