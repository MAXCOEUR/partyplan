import 'package:flutter/material.dart';

import '../../l10n/generated/pp_localisations.dart';
import '../tokens.dart';

/// Statut de présence, tel que défini par EF-PRES-01.
enum PpPresence { inconnu, present, peutEtre, absent, arriveTard, partTot }

/// Pastille de statut de présence.
///
/// « Arrive plus tard » et « part plus tôt » reçoivent la couleur des présents, car ils
/// comptent comme tels (RG-PRES-02). « Peut-être » est visuellement distinct : c'est la
/// seule réponse qui n'entre pas dans la répartition des dépenses (RG-PRES-03), et
/// l'organisateur doit le voir.
class PpStatusChip extends StatelessWidget {
  const PpStatusChip({
    required this.presence,
    this.heure,
    this.neutre = false,
    super.key,
  });

  final PpPresence presence;

  /// Heure d'arrivée ou de départ annoncée, déjà formatée.
  final String? heure;

  /// Rend la pastille sans sa couleur sémantique.
  ///
  /// Sert aux listes de choix : proposer cinq réponses avec cinq couleurs met cinq
  /// accents sur un écran et rend la réponse retenue indiscernable des autres. Les
  /// options restent neutres, seule celle qui est choisie porte sa couleur — c'est elle
  /// qui répond à la question posée par la carte.
  final bool neutre;

  @override
  Widget build(BuildContext context) {
    final (couleurSemantique, icone) = _apparence();
    final schema = Theme.of(context).colorScheme;
    final libelle = _libelle(PpL10n.of(context));

    final couleurBrute = neutre ? schema.onSurfaceVariant : couleurSemantique;

    // Le fond conserve la couleur de charte à 12 % ; le texte et l'icône prennent la
    // variante accessible (NF-A11Y-01).
    final couleur = neutre
        ? schema.onSurfaceVariant
        : PpColors.texteSur(couleurBrute, Theme.of(context).brightness);
    final texte = heure == null ? libelle : '$libelle · $heure';

    return Semantics(
      label: texte,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(
          horizontal: PpSpacing.md,
          vertical: PpSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: neutre
              ? schema.surfaceContainerHigh
              : couleurBrute.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PpRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: PpSpacing.xs),
            Text(
              texte,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: couleur,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Couleur et icône. « Arrive plus tard » et « part plus tôt » reçoivent la couleur
  /// des présents, car ils comptent comme tels (RG-PRES-02).
  (Color, IconData) _apparence() => switch (presence) {
    PpPresence.present => (PpColors.vert, Icons.check_rounded),
    PpPresence.arriveTard => (PpColors.vert, Icons.schedule_rounded),
    PpPresence.partTot => (PpColors.vert, Icons.logout_rounded),
    PpPresence.peutEtre => (PpColors.orange, Icons.help_outline_rounded),
    PpPresence.absent => (PpColors.texteSecondaireClair, Icons.close_rounded),
    PpPresence.inconnu => (PpColors.texteSecondaireClair, Icons.remove_rounded),
  };

  /// Libellé traduit.
  ///
  /// Séparé de l'apparence, et pris dans le contexte : les libellés étaient écrits en
  /// dur dans ce composant, ce qui violait NF-I18N-01. Le défaut est resté invisible
  /// tant qu'aucun écran n'affichait de statut.
  String _libelle(PpL10n l10n) => switch (presence) {
    PpPresence.present => l10n.statutPresent,
    PpPresence.arriveTard => l10n.statutEnRetard,
    PpPresence.partTot => l10n.statutPartAvant,
    PpPresence.peutEtre => l10n.statutPeutEtre,
    PpPresence.absent => l10n.statutAbsent,
    PpPresence.inconnu => l10n.statutInconnu,
  };
}
