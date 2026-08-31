import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/message.dart';
import 'package:partyplan/design/components/pp_texte_message.dart';
import 'package:partyplan/design/tokens.dart';

Future<void> _monter(
  WidgetTester tester,
  String texte, {
  List<Mention> mentions = const [],
  void Function(String)? surLien,
  bool surAplat = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: PpTexteMessage(
        texte: texte,
        mentions: mentions,
        surLien: surLien ?? (_) {},
        surAplat: surAplat,
      ),
    ),
  ),
);

/// Liens ouverts pendant un test.
final _ouverts = <String>[];

void main() {
  group('PpTexteMessage sur un aplat', () {
    // Une bulle « mienne » est peinte avec la couleur primaire, c'est-à-dire le violet
    // que mentions et liens emploient pour se distinguer. Peints dessus, ils
    // disparaissent purement et simplement : la couleur qui les met en évidence
    // ailleurs est exactement celle du fond ici.

    testWidgets('la mention ne reprend pas la couleur du fond', (tester) async {
      await _monter(
        tester,
        'salut @Camille',
        mentions: const [Mention(membreId: 'm1', nom: 'Camille')],
        surAplat: true,
      );

      final couleur = _couleurDe(tester, '@Camille');

      expect(couleur, isNot(PpColors.violet));
      expect(
        couleur,
        isNot(PpColors.texteSur(PpColors.violet, Brightness.light)),
      );
    });

    testWidgets('le lien ne reprend pas la couleur du fond', (tester) async {
      // Même défaut, moins visible parce que moins fréquent : un lien collé dans son
      // propre message était illisible lui aussi.
      await _monter(
        tester,
        'la playlist : https://open.spotify.com/playlist/37i9',
        surAplat: true,
      );

      final couleur = _couleurDe(
        tester,
        'https://open.spotify.com/playlist/37i9',
      );

      expect(couleur, isNot(PpColors.violet));
      expect(
        couleur,
        isNot(PpColors.texteSur(PpColors.violet, Brightness.light)),
      );
    });

    testWidgets('le lien reste souligné, faute de pouvoir rester coloré', (
      tester,
    ) async {
      // Sur l'aplat, la couleur ne peut plus signaler le lien : c'est le soulignement
      // qui porte alors seul l'information.
      await _monter(
        tester,
        'voir https://exemple.fr',
        surAplat: true,
      );

      expect(
        _styleDe(tester, 'https://exemple.fr')?.decoration,
        TextDecoration.underline,
      );
    });

    testWidgets('hors aplat, la mention garde la couleur d’accent', (
      tester,
    ) async {
      await _monter(
        tester,
        'salut @Camille',
        mentions: const [Mention(membreId: 'm1', nom: 'Camille')],
      );

      expect(
        _couleurDe(tester, '@Camille'),
        PpColors.texteSur(PpColors.violet, Brightness.light),
      );
    });
  });

  group('PpTexteMessage', () {
    testWidgets('rend un texte ordinaire tel quel', (tester) async {
      await _monter(tester, 'On se retrouve à 20 h');

      expect(find.textContaining('On se retrouve à 20 h'), findsOneWidget);
    });

    testWidgets('détecte un lien et le rend cliquable', (tester) async {
      // Un lien donné en texte brut obligerait à le recopier à la main.
      var ouvert = '';

      await _monter(
        tester,
        'la playlist : https://open.spotify.com/playlist/37i9',
        surLien: (url) => ouvert = url,
      );

      // Le lien est un fragment de texte, non un widget : on l'atteint par son
      // contenu, ce qui vérifie aussi qu'il est bien rendu comme du texte coupable en
      // fin de ligne.
      await tester.tapOnText(
        find.textRange.ofSubstring('https://open.spotify.com/playlist/37i9'),
      );
      await tester.pumpAndSettle();

      expect(ouvert, 'https://open.spotify.com/playlist/37i9');
    });

    testWidgets('un lien en fin de phrase ne mange pas la ponctuation', (
      tester,
    ) async {
      // « Regarde ça : https://exemple.fr. » ne doit pas produire un lien terminé par
      // un point, qui ne mènerait nulle part.
      var ouvert = '';

      await _monter(
        tester,
        'regarde https://exemple.fr.',
        surLien: (url) => ouvert = url,
      );

      await tester.tapOnText(find.textRange.ofSubstring('https://exemple.fr'));
      await tester.pumpAndSettle();

      expect(ouvert, 'https://exemple.fr');
    });

    testWidgets('détecte plusieurs liens dans un même message', (tester) async {
      _ouverts.clear();

      await _monter(
        tester,
        'ici https://un.fr et là https://deux.fr',
        surLien: _ouverts.add,
      );

      var ouverts = <String>[];
      await tester.tapOnText(find.textRange.ofSubstring('https://un.fr'));
      await tester.pumpAndSettle();
      ouverts = [..._ouverts];

      expect(ouverts, contains('https://un.fr'));

      await tester.tapOnText(find.textRange.ofSubstring('https://deux.fr'));
      await tester.pumpAndSettle();

      expect(_ouverts, contains('https://deux.fr'));
    });

    testWidgets('un lien sans protocole reste du texte', (tester) async {
      // Ouvrir « exemple.fr » exigerait de deviner le protocole, et « 20h.30 »
      // deviendrait un lien.
      _ouverts.clear();

      await _monter(
        tester,
        'rendez-vous à 20h.30 chez exemple.fr',
        surLien: _ouverts.add,
      );

      await tester.tapOnText(find.textRange.ofSubstring('exemple.fr'));
      await tester.pumpAndSettle();

      expect(_ouverts, isEmpty);
    });

    testWidgets('met une mention en évidence', (tester) async {
      await _monter(
        tester,
        '@Lucas tu apportes l’enceinte ?',
        mentions: const [Mention(membreId: 'm2', nom: 'Lucas')],
      );

      expect(find.byKey(const Key('mention-m2')), findsOneWidget);
    });

    testWidgets('une mention absente du texte n’invente rien', (tester) async {
      // Le serveur enregistre la mention, mais l'auteur peut avoir réécrit son
      // message sans le nom : rien ne doit être ajouté au texte.
      await _monter(
        tester,
        'tu apportes l’enceinte ?',
        mentions: const [Mention(membreId: 'm2', nom: 'Lucas')],
      );

      expect(find.byKey(const Key('mention-m2')), findsNothing);
      expect(find.textContaining('tu apportes'), findsOneWidget);
    });

    testWidgets('un lien et une mention cohabitent', (tester) async {
      await _monter(
        tester,
        '@Lucas voilà https://un.fr',
        mentions: const [Mention(membreId: 'm2', nom: 'Lucas')],
        surLien: _ouverts.add,
      );

      _ouverts.clear();

      expect(find.byKey(const Key('mention-m2')), findsOneWidget);

      await tester.tapOnText(find.textRange.ofSubstring('https://un.fr'));
      await tester.pumpAndSettle();

      expect(_ouverts, contains('https://un.fr'));
    });
  });
}


/// Style effectif d'un fragment de texte, mention comprise.
///
/// Une mention est un widget posé dans le flux, un lien un fragment de `Text.rich` :
/// les deux se retrouvent par leur contenu, ce qui évite de dépendre de la structure.
TextStyle? _styleDe(WidgetTester tester, String contenu) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    if (widget.data == contenu) {
      return widget.style;
    }

    final morceau = _chercherDansSpan(widget.textSpan, contenu);
    if (morceau != null) {
      return morceau;
    }
  }

  return null;
}

Color? _couleurDe(WidgetTester tester, String contenu) =>
    _styleDe(tester, contenu)?.color;

TextStyle? _chercherDansSpan(InlineSpan? span, String contenu) {
  if (span is TextSpan) {
    if (span.text == contenu) {
      return span.style;
    }

    for (final enfant in span.children ?? const <InlineSpan>[]) {
      final trouve = _chercherDansSpan(enfant, contenu);
      if (trouve != null) {
        return trouve;
      }
    }
  }

  return null;
}
