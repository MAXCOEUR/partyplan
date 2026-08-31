import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/models/message.dart';
import '../tokens.dart';

/// Corps d'un message, avec ses liens cliquables et ses mentions en évidence.
///
/// Un lien laissé en texte brut oblige à le recopier à la main, ce qui suffit à ce
/// qu'on ne l'ouvre jamais. Une mention noyée dans la phrase ne se remarque pas, alors
/// que c'est précisément ce qui appelle une réponse.
///
/// Les deux traitements sont faits ici, à l'affichage, sur un texte que le serveur
/// stocke tel qu'il a été écrit : y insérer du balisage rendrait le message
/// dépendant du client qui l'a envoyé.
class PpTexteMessage extends StatelessWidget {
  const PpTexteMessage({
    required this.texte,
    required this.surLien,
    this.mentions = const [],
    this.style,
    this.surAplat = false,
    super.key,
  });

  final String texte;

  /// Personnes citées, telles que le serveur les a enregistrées. Une mention dont le
  /// nom ne figure plus dans le texte n'ajoute rien : l'auteur a pu réécrire son
  /// message.
  final List<Mention> mentions;

  final void Function(String url) surLien;

  final TextStyle? style;

  /// Vrai lorsque le texte est posé sur un aplat de la couleur d'accent — la bulle de
  /// ses propres messages.
  ///
  /// Sans cette distinction, mentions et liens se peignent de la couleur exacte du fond
  /// et disparaissent : ce qui les met en évidence ailleurs est ici ce qui les efface.
  final bool surAplat;

  /// Reconnaît une adresse commençant par un protocole explicite.
  ///
  /// Le protocole est exigé : sans lui, « rendez-vous à 20h.30 » deviendrait un lien,
  /// et ouvrir « exemple.fr » demanderait de deviner s'il faut http ou https.
  static final _lien = RegExp(r'(https?://[^\s]+)');

  /// Caractères de fin de phrase, retirés d'un lien qui les capterait.
  ///
  /// « Regarde https://exemple.fr. » ne doit pas produire un lien terminé par un
  /// point, qui ne mènerait nulle part.
  static const _ponctuationFinale = '.,;:!?)»"\'';

  /// Couleur de mise en évidence, selon le fond.
  ///
  /// Sur l'aplat, `onPrimary` est la seule qui garantisse le contraste — c'est la
  /// couleur que le thème associe à cet aplat, et le reste du message l'emploie déjà.
  static Color _accent(BuildContext context, {required bool surAplat}) {
    final theme = Theme.of(context);

    return surAplat
        ? theme.colorScheme.onPrimary
        : PpColors.texteSur(PpColors.violet, theme.brightness);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium!;

    return Text.rich(
      TextSpan(children: _fragments(context, base)),
      style: base,
    );
  }

  List<InlineSpan> _fragments(BuildContext context, TextStyle base) {
    final fragments = <InlineSpan>[];

    var position = 0;

    for (final trouve in _lien.allMatches(texte)) {
      if (trouve.start > position) {
        fragments.addAll(
          _avecMentions(context, texte.substring(position, trouve.start), base),
        );
      }

      final brut = trouve.group(0)!;
      final url = _sansPonctuationFinale(brut);

      fragments.add(
        TextSpan(
          text: url,
          style: base.copyWith(
            color: _accent(context, surAplat: surAplat),
            // Le soulignement ne dépend pas du fond : sur l'aplat, la couleur ne peut
            // plus distinguer le lien du texte, et il reste seul à le signaler.
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => surLien(url),
          // La clé sert à viser le lien dans les tests et à l'annoncer aux
          // technologies d'assistance.
          semanticsLabel: 'Lien : $url',
        ),
      );

      // Le morceau de ponctuation retiré du lien revient au texte.
      if (url.length < brut.length) {
        fragments.add(TextSpan(text: brut.substring(url.length)));
      }

      position = trouve.end;
    }

    if (position < texte.length) {
      fragments.addAll(_avecMentions(context, texte.substring(position), base));
    }

    return fragments;
  }

  /// Découpe un fragment de texte pour mettre les noms cités en évidence.
  List<InlineSpan> _avecMentions(
    BuildContext context,
    String fragment,
    TextStyle base,
  ) {
    if (mentions.isEmpty) {
      return [TextSpan(text: fragment)];
    }

    final morceaux = <InlineSpan>[];
    var reste = fragment;

    while (reste.isNotEmpty) {
      // La mention la plus proche dans ce qui reste : traiter dans l'ordre du texte
      // évite qu'un nom court découpe un nom long qui le contient.
      ({int index, Mention mention, String motif})? prochaine;

      for (final mention in mentions) {
        final motif = '@${mention.nom}';
        final index = reste.indexOf(motif);

        if (index >= 0 && (prochaine == null || index < prochaine.index)) {
          prochaine = (index: index, mention: mention, motif: motif);
        }
      }

      if (prochaine == null) {
        morceaux.add(TextSpan(text: reste));
        break;
      }

      if (prochaine.index > 0) {
        morceaux.add(TextSpan(text: reste.substring(0, prochaine.index)));
      }

      morceaux.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _Mention(
            key: Key('mention-${prochaine.mention.membreId}'),
            nom: prochaine.mention.nom,
            surAplat: surAplat,
          ),
        ),
      );

      reste = reste.substring(prochaine.index + prochaine.motif.length);
    }

    return morceaux;
  }

  static String _sansPonctuationFinale(String url) {
    var propre = url;

    while (propre.isNotEmpty &&
        _ponctuationFinale.contains(propre[propre.length - 1])) {
      propre = propre.substring(0, propre.length - 1);
    }

    return propre;
  }
}

/// Nom cité, sur un fond léger. Assez visible pour qu'on se sache appelé.
class _Mention extends StatelessWidget {
  const _Mention({required this.nom, required this.surAplat, super.key});

  final String nom;

  final bool surAplat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = PpTexteMessage._accent(context, surAplat: surAplat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        // Le fond se teinte de l'accent lui-même : sur un aplat violet, un voile violet
        // ne se distingue pas, là où un voile clair détache la puce.
        color: accent.withValues(alpha: surAplat ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(PpRadius.sm),
      ),
      child: Text(
        '@$nom',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
