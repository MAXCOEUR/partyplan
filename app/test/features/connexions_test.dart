import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/router.dart';
import 'package:partyplan/core/models/moyens_connexion.dart';
import 'package:partyplan/core/providers.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/features/profil/connexions_page.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Modèle des moyens de connexion', () {
    test('lit la réponse de l’API', () {
      final moyens = MoyensConnexion.depuisJson({
        'hasPassword': true,
        'providers': [
          {'provider': 'google', 'configured': true, 'linked': false},
          {'provider': 'apple', 'configured': false, 'linked': false},
        ],
      });

      expect(moyens.aUnMotDePasse, isTrue);
      expect(moyens.fournisseurs.length, 2);
      expect(moyens.fournisseurs.first.identifiant, 'google');
      expect(moyens.fournisseurs.first.disponible, isTrue);
      expect(moyens.fournisseurs.last.disponible, isFalse);
    });

    test('compte le mot de passe parmi les moyens de connexion', () {
      final avecMotDePasse = MoyensConnexion.depuisJson({
        'hasPassword': true,
        'providers': [
          {'provider': 'google', 'configured': true, 'linked': true},
        ],
      });

      // Deux moyens : détacher Google laisse le mot de passe.
      expect(avecMotDePasse.nombre, 2);
      expect(
        avecMotDePasse.peutDetacher(avecMotDePasse.fournisseurs.first),
        isTrue,
      );
    });

    test('refuse le détachement du dernier moyen de connexion', () {
      // Sans mot de passe, détacher l'unique fournisseur enfermerait dehors : c'est
      // le refus que le serveur oppose, l'écran doit l'anticiper.
      final unique = MoyensConnexion.depuisJson({
        'hasPassword': false,
        'providers': [
          {'provider': 'google', 'configured': true, 'linked': true},
        ],
      });

      expect(unique.nombre, 1);
      expect(unique.peutDetacher(unique.fournisseurs.first), isFalse);
    });

    test('un fournisseur non rattaché n’est pas détachable', () {
      final aucun = MoyensConnexion.depuisJson({
        'hasPassword': true,
        'providers': [
          {'provider': 'google', 'configured': true, 'linked': false},
        ],
      });

      expect(aucun.peutDetacher(aucun.fournisseurs.first), isFalse);
    });

    test('donne un libellé lisible plutôt que l’identifiant technique', () {
      expect(
        const MoyenTiers(
          identifiant: 'google',
          disponible: true,
          rattache: false,
        ).libelle,
        'Google',
      );
      expect(
        const MoyenTiers(
          identifiant: 'apple',
          disponible: true,
          rattache: false,
        ).libelle,
        'Apple',
      );
      // Un fournisseur ajouté côté serveur ne doit pas casser l'écran.
      expect(
        const MoyenTiers(
          identifiant: 'inconnu',
          disponible: true,
          rattache: false,
        ).libelle,
        'inconnu',
      );
    });
  });

  group('Écran des connexions', () {
    testWidgets('annonce ce qui est indisponible sur l’instance', (
      tester,
    ) async {
      await _monter(
        tester,
        const MoyensConnexion(
          aUnMotDePasse: true,
          fournisseurs: [
            MoyenTiers(
              identifiant: 'apple',
              disponible: false,
              rattache: false,
            ),
          ],
        ),
      );

      // Offrir un bouton qui échouera à coup sûr est pire que ne rien offrir.
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Rattacher'), findsNothing);
      expect(find.textContaining('pas disponible'), findsOneWidget);
    });

    testWidgets(
      'distingue « pas configuré » de « pas encore dans l’application »',
      (tester) async {
        await _monter(
          tester,
          const MoyensConnexion(
            aUnMotDePasse: true,
            fournisseurs: [
              MoyenTiers(
                identifiant: 'google',
                disponible: true,
                rattache: false,
              ),
            ],
          ),
        );

        // Le serveur sait vérifier un jeton Google, mais l'application ne sait pas encore
        // en obtenir un : le dire est plus utile qu'un bouton mort.
        expect(find.text('Rattacher'), findsNothing);
        expect(find.textContaining('depuis l’application'), findsOneWidget);
      },
    );

    testWidgets('explique pourquoi le dernier moyen n’est pas détachable', (
      tester,
    ) async {
      await _monter(
        tester,
        const MoyensConnexion(
          aUnMotDePasse: false,
          fournisseurs: [
            MoyenTiers(identifiant: 'google', disponible: true, rattache: true),
          ],
        ),
      );

      expect(find.textContaining('seul moyen de connexion'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Détacher'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('permet le détachement quand un mot de passe existe', (
      tester,
    ) async {
      await _monter(
        tester,
        const MoyensConnexion(
          aUnMotDePasse: true,
          fournisseurs: [
            MoyenTiers(identifiant: 'google', disponible: true, rattache: true),
          ],
        ),
      );

      expect(find.text('Mot de passe'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Détacher'),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('Routage des connexions', () {
    test('l’écran des connexions n’est pas public', () {
      expect(PpRoutes.publiques, isNot(contains(PpRoutes.connexionsTierces)));
    });
  });
}

Future<void> _monter(WidgetTester tester, MoyensConnexion moyens) async {
  final conteneur = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(SessionStoreDouble()),
      moyensConnexionProvider.overrideWith((ref) async => moyens),
    ],
  );
  addTearDown(conteneur.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp(
        // Mêmes délégués que l'application : sans eux, PpL10n.of échoue.
        localizationsDelegates: PartyPlanApp.delegues,
        supportedLocales: PartyPlanApp.languesPrisesEnCharge,
        locale: const Locale('fr'),
        home: const ConnexionsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
