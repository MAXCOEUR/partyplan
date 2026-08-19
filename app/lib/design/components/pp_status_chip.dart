import 'package:flutter/material.dart';

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
  const PpStatusChip({required this.presence, this.heure, super.key});

  final PpPresence presence;

  /// Heure d'arrivée ou de départ annoncée, déjà formatée.
  final String? heure;

  @override
  Widget build(BuildContext context) {
    final (libelle, couleurBrute, icone) = _apparence();
    // Le fond conserve la couleur de charte à 12 % ; le texte et l'icône prennent la
    // variante accessible (NF-A11Y-01).
    final couleur = PpColors.texteSur(
      couleurBrute,
      Theme.of(context).brightness,
    );
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
          color: couleurBrute.withValues(alpha: 0.12),
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

  (String, Color, IconData) _apparence() => switch (presence) {
    PpPresence.present => ('Présent', PpColors.vert, Icons.check_rounded),
    PpPresence.arriveTard => (
      'Arrive plus tard',
      PpColors.vert,
      Icons.schedule_rounded,
    ),
    PpPresence.partTot => (
      'Part plus tôt',
      PpColors.vert,
      Icons.logout_rounded,
    ),
    PpPresence.peutEtre => (
      'Peut-être',
      PpColors.orange,
      Icons.help_outline_rounded,
    ),
    PpPresence.absent => (
      'Absent',
      PpColors.texteSecondaireClair,
      Icons.close_rounded,
    ),
    PpPresence.inconnu => (
      'Sans réponse',
      PpColors.texteSecondaireClair,
      Icons.remove_rounded,
    ),
  };
}
