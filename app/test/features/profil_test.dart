import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/profil.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/profil/profil_page.dart';

import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

Profil _profil({String role = 'User'}) => Profil(
  id: 'u1',
  email: 'moi@partyplan.local',
  emailVerifie: true,
  nomAffiche: 'Maxence',
  urlPhoto: null,
  langue: 'fr-FR',
  fuseau: 'Europe/Paris',
  rolePlateforme: role,
  aUnMotDePasse: true,
  motDePasseAChanger: false,
  creeLe: DateTime(2026, 8, 1),
);

Future<void> _monter(WidgetTester tester, {String role = 'User'}) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: 'jeton'),
      ),
      profilProvider.overrideWith((ref) async => _profil(role: role)),
      mesEvenementsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(conteneur.dispose);

  await monterEcran(tester, const ProfilPage(), conteneur: conteneur);
}

void main() {
  group('Mon profil', () {
    testWidgets('la déconnexion est un bouton, pas une icône à deviner', (
      tester,
    ) async {
      // Une icône dans la barre ne se trouve pas : se déconnecter est un geste
      // ordinaire, il doit être nommé.
      await _monter(tester);

      expect(find.text('Se déconnecter'), findsWidgets);
    });

    testWidgets('la suppression du compte est atteignable directement', (
      tester,
    ) async {
      // Elle était enfouie dans « Mes données et confidentialité » : personne ne
      // cherche là pour fermer son compte.
      await _monter(tester);

      expect(find.text('Supprimer mon compte'), findsOneWidget);
    });

    testWidgets('un administrateur de plateforme ne se supprime pas ici', (
      tester,
    ) async {
      // Le serveur refuse tant que le rôle n'est pas transféré : proposer le geste
      // pour le voir échouer vaudrait moins que l'expliquer.
      await _monter(tester, role: 'PlatformAdmin');

      expect(find.text('Supprimer mon compte'), findsNothing);
      expect(find.textContaining('transfère ce rôle'), findsOneWidget);
    });

    testWidgets('les entrées du compte restent accessibles', (tester) async {
      await _monter(tester);

      expect(find.text('Modifier mon profil'), findsOneWidget);
      expect(find.text('Sécurité et sessions'), findsOneWidget);
      expect(find.text('Mes données et confidentialité'), findsOneWidget);
    });
  });
}
