import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/activite.dart';
import '../../design/components/pp_apparition.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'phrase_activite.dart';

/// Une ligne du registre : l'avatar posé sur le filet, la phrase, l'heure.
///
/// **Le filet vertical est la signature de cet écran.** Il court d'une ligne à l'autre
/// et fait lire l'ensemble comme un registre continu plutôt que comme une pile
/// d'éléments. C'est lui qui remplace la carte : ici rien ne se touche, et une surface
/// qui ressemble à une carte laisserait croire l'inverse (`RG-FIL-02`).
///
/// Aucune icône par catégorie : le verbe de la phrase dit déjà ce qui s'est passé, et
/// treize pictogrammes auraient donné un tableau de bord d'entreprise là où il faut une
/// soirée entre amis.
class LigneActivite extends StatelessWidget {
  const LigneActivite({
    required this.activite,
    required this.rang,
    required this.debuteUnJour,
    required this.premiere,
    required this.derniere,
    super.key,
  });

  final Activite activite;

  /// Rang dans la liste, pour l'entrée en cascade.
  final int rang;

  /// Première ligne d'un jour : un marqueur de date la précède.
  final bool debuteUnJour;

  final bool premiere;

  /// Dernière ligne connue du fil : le filet s'arrête sous elle.
  final bool derniere;

  /// Diamètre de l'avatar. Le filet passe par son centre.
  static const _tailleAvatar = 32.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = PpL10n.of(context);
    final sombre = theme.brightness == Brightness.dark;

    final filet = sombre ? PpColors.bordureSombre : PpColors.bordureClaire;
    final secondaire = sombre
        ? PpColors.texteSecondaireSombre
        : PpColors.texteSecondaireClair;

    final phrase = phraseActivite(l10n, activite);

    return PpApparition(
      rang: rang,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (debuteUnJour)
            _MarqueurDeJour(
              jour: activite.creeLe,
              premier: premiere,
              couleurFilet: filet,
              couleurTexte: secondaire,
              decalage: _tailleAvatar,
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _tailleAvatar,
                  child: Column(
                    children: [
                      PpAvatar(
                        nom: activite.auteur,
                        urlPhoto: activite.avatarUrl,
                        taille: _tailleAvatar,
                      ),
                      // Le filet reprend sous l'avatar et rejoint la ligne suivante.
                      // Il s'arrête à la dernière ligne connue : le prolonger dans le
                      // vide annoncerait une suite qui n'existe pas.
                      if (!derniere)
                        Expanded(
                          child: Container(width: 1, color: filet),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: PpSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: PpSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Une seule lecture pour la synthèse vocale : la phrase
                        // découpée en fragments stylés serait lue en morceaux.
                        Semantics(
                          label: '${activite.auteur} $phrase',
                          excludeSemantics: true,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: activite.auteur,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: phrase,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat.Hm('fr_FR').format(activite.creeLe),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaire,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Séparateur de jour : le filet s'interrompt, la date s'inscrit à sa place.
///
/// Un registre se lit par journées. Sans cette respiration, une soirée préparée sur
/// deux semaines devient un mur de lignes où rien ne situe rien.
class _MarqueurDeJour extends StatelessWidget {
  const _MarqueurDeJour({
    required this.jour,
    required this.premier,
    required this.couleurFilet,
    required this.couleurTexte,
    required this.decalage,
  });

  final DateTime jour;
  final bool premier;
  final Color couleurFilet;
  final Color couleurTexte;
  final double decalage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = PpL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le filet monte jusqu'au marqueur, sauf en tête de liste où il n'y a rien
        // au-dessus.
        if (!premier)
          Padding(
            padding: EdgeInsets.only(left: decalage / 2),
            child: Container(width: 1, height: PpSpacing.sm, color: couleurFilet),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PpSpacing.sm),
          child: Text(
            _libelle(l10n),
            style: theme.textTheme.labelSmall?.copyWith(
              color: couleurTexte,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Le filet reprend sous le marqueur et rejoint la première ligne du jour.
        Padding(
          padding: EdgeInsets.only(left: decalage / 2),
          child: Container(width: 1, height: PpSpacing.sm, color: couleurFilet),
        ),
      ],
    );
  }

  String _libelle(PpL10n l10n) {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final leJour = DateTime(jour.year, jour.month, jour.day);
    final ecart = aujourdhui.difference(leJour).inDays;

    // « Aujourd'hui » et « Hier » plutôt qu'une date : ce sont les deux journées qu'on
    // consulte, et une date les rendrait à déchiffrer.
    return switch (ecart) {
      0 => l10n.filAujourdhui.toUpperCase(),
      1 => l10n.filHier.toUpperCase(),
      _ => DateFormat('d MMMM', 'fr_FR').format(jour).toUpperCase(),
    };
  }
}
