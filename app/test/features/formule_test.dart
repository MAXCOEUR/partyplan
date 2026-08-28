import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/membre.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/features/accueil/accueil_page.dart';
import 'package:partyplan/features/profil/profil_page.dart';

import '../aide/fabriques.dart';
import '../aide/monter_ecran.dart';
import '../doubles/session_store_double.dart';

EvenementDeLaListe _evenement({
  required String id,
  required RoleMembre role,
  required bool passe,
}) => EvenementDeLaListe(
  id: id,
  nom: 'Soirée $id',
  debut: DateTime(2026, 9, 15),
  fin: null,
  adresse: null,
  imageCouverture: null,
  invites: 4,
  presents: 3,
  monRole: role,
  monStatut: StatutPresence.present,
  estPasse: passe,
);

ProviderContainer _conteneur({
  DateTime? premiumJusquau,
  List<EvenementDeLaListe> evenements = const [],
}) {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        SessionStoreDouble(jetonAcces: 'jeton'),
      ),
      profilProvider.overrideWith(
        (ref) async => profilDeTest(premiumJusquau: premiumJusquau),
      ),
      mesEvenementsProvider.overrideWith((ref) async => evenements),
    ],
  );

  return conteneur;
}

void main() {
  group('Formule au profil', () {
    testWidgets('un compte sans échéance est annoncé gratuit', (tester) async {
      final conteneur = _conteneur();
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const ProfilPage(), conteneur: conteneur);

      expect(find.text('Gratuit'), findsOneWidget);
    });

    testWidgets('une échéance est affichée en JJ/MM/AAAA', (tester) async {
      // La date est locale et volontairement en milieu de journée : une échéance à
      // minuit UTC basculerait de jour selon le fuseau, et le test deviendrait faux
      // une partie de l'année.
      final conteneur = _conteneur(premiumJusquau: DateTime(2026, 9, 28, 12));
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const ProfilPage(), conteneur: conteneur);

      expect(find.text('Premium jusqu\'au 28/09/2026'), findsOneWidget);
    });

    testWidgets('une échéance passée redevient gratuite', (tester) async {
      // Aucune tâche ne remet le champ à nul côté serveur : c'est la comparaison qui
      // fait foi, ici comme là-bas.
      final conteneur = _conteneur(premiumJusquau: DateTime(2020, 1, 1));
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const ProfilPage(), conteneur: conteneur);

      expect(find.text('Gratuit'), findsOneWidget);
    });
  });

  group('Quota sur l\'accueil', () {
    testWidgets('le quota consommé compte les soirées possédées à venir', (
      tester,
    ) async {
      final conteneur = _conteneur(
        evenements: [
          _evenement(id: 'a', role: RoleMembre.proprietaire, passe: false),
          _evenement(id: 'b', role: RoleMembre.proprietaire, passe: false),
          // Passée : sa place est rendue.
          _evenement(id: 'c', role: RoleMembre.proprietaire, passe: true),
          // Membre sans posséder : ne consomme rien.
          _evenement(id: 'd', role: RoleMembre.membre, passe: false),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
      await tester.pumpAndSettle();

      expect(find.text('2 soirées sur 3'), findsOneWidget);
    });

    testWidgets('le singulier est accordé', (tester) async {
      final conteneur = _conteneur(
        evenements: [
          _evenement(id: 'a', role: RoleMembre.proprietaire, passe: false),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
      await tester.pumpAndSettle();

      expect(find.text('1 soirée sur 3'), findsOneWidget);
    });

    testWidgets('un abonné ne voit aucun quota', (tester) async {
      final conteneur = _conteneur(
        premiumJusquau: DateTime(2099, 1, 1),
        evenements: [
          _evenement(id: 'a', role: RoleMembre.proprietaire, passe: false),
        ],
      );
      addTearDown(conteneur.dispose);

      await monterEcran(tester, const AccueilPage(), conteneur: conteneur);
      await tester.pumpAndSettle();

      expect(find.textContaining('sur 3'), findsNothing);
    });
  });
}
