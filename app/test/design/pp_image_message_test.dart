import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:partyplan/design/components/pp_image_message.dart';

/// La vignette et son agrandissement sont montés sur un routeur, comme dans
/// l'application : c'est le routeur qui porte l'aller-retour, et le tester sans lui
/// laisserait passer un « précédent » de navigateur qui referme la mauvaise chose.
Future<GoRouter> _poser(WidgetTester tester, {String? etiquette}) async {
  final routeur = GoRouter(
    initialLocation: '/fil',
    routes: [
      GoRoute(
        path: '/fil',
        builder: (context, state) => Scaffold(
          body: PpImageMessage(
            url: 'https://exemple.test/apero.webp',
            adresseAgrandie: '/image',
            etiquette: etiquette,
          ),
        ),
      ),
      GoRoute(
        path: '/image',
        pageBuilder: (context, state) => const MaterialPage(
          child: PpVisionneuseImage(
            url: 'https://exemple.test/apero.webp',
            versParent: '/fil',
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: routeur));
  await tester.pumpAndSettle();

  return routeur;
}

void main() {
  group('PpImageMessage', () {
    testWidgets('ouvre l’image en plein écran au clic', (tester) async {
      // Une vignette de 200 points ne montre pas qui est sur la photo : le geste
      // attendu d'une image dans une conversation est de l'agrandir.
      await _poser(tester);

      expect(find.byType(PpVisionneuseImage), findsNothing);

      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      expect(find.byType(PpVisionneuseImage), findsOneWidget);
    });

    testWidgets('l’agrandissement est une adresse à part', (tester) async {
      // Sans adresse propre, le « précédent » du navigateur ne voit pas l'image et
      // referme la discussion à sa place.
      final routeur = await _poser(tester);

      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      expect(routeur.state.uri.toString(), '/image');
    });

    testWidgets('l’image agrandie se laisse zoomer et déplacer', (
      tester,
    ) async {
      // Un plan large, une capture d'écran d'adresse : sans zoom, l'agrandissement
      // n'apporte rien de plus que la vignette.
      await _poser(tester);
      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('l’image agrandie occupe tout l’écran', (tester) async {
      // Agrandir doit agrandir : une photo laissée à sa taille de fichier peut occuper
      // un quart de l'écran, et le geste n'aura rien donné.
      await _poser(tester);
      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('image-plein-ecran'))),
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
    });

    testWidgets('se referme et rend la conversation', (tester) async {
      await _poser(tester);
      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(PpVisionneuseImage), findsNothing);
      expect(find.byType(PpImageMessage), findsOneWidget);
    });

    testWidgets('le retour système referme l’image, pas la conversation', (
      tester,
    ) async {
      // L'agrandissement est une couche par-dessus le fil : le retour la retire.
      final routeur = await _poser(tester);
      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PpVisionneuseImage), findsNothing);
      expect(routeur.state.uri.toString(), '/fil');
    });

    testWidgets('Échap referme l’image', (tester) async {
      // Sur un écran, la main est au clavier : Échap est le geste attendu.
      await _poser(tester);
      await tester.tap(find.byType(PpImageMessage));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(PpVisionneuseImage), findsNothing);
    });

    testWidgets('s’annonce comme une image agrandissable', (tester) async {
      // NF-A11Y : sans étiquette, un lecteur d'écran ne rencontre qu'un bouton muet.
      final semantique = tester.ensureSemantics();
      await _poser(tester, etiquette: 'Photo envoyée par Lucas');

      expect(
        find.bySemanticsLabel('Photo envoyée par Lucas, agrandir'),
        findsOneWidget,
      );

      semantique.dispose();
    });
  });
}
