import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tokens.dart';
import '../typography.dart';

/// Date d'un événement, présentée comme sur un carton d'invitation.
///
/// « C'est quand ? » est la première question devant une liste de soirées. La réponse
/// est donc traitée comme un objet à part entière — jour en gros chiffre, mois abrégé
/// dessous — et non comme une ligne de texte à lire parmi d'autres.
///
/// Une date absente est un cas normal, pas une donnée manquante : un événement peut
/// naître avant que le jour soit choisi, et la pastille le dit alors explicitement.
class PpDatePastille extends StatelessWidget {
  const PpDatePastille({
    required this.date,
    this.avecHeure = false,
    this.estompee = false,
    super.key,
  });

  /// Nul lorsque le jour n'est pas encore fixé.
  final DateTime? date;

  /// Ajoute l'heure sous le mois. Réservé aux écrans où elle compte : dans une liste,
  /// elle ajoute une ligne sans répondre à la question posée.
  final bool avecHeure;

  /// Soirée passée : la pastille s'efface sans devenir illisible.
  final bool estompee;

  static final _jour = DateFormat('d', 'fr_FR');
  static final _mois = DateFormat('MMM', 'fr_FR');
  static final _heure = DateFormat('HH:mm', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final valeur = date;

    // Le dégradé de marque sur la soirée à venir, un aplat neutre sur les autres :
    // employé partout, le dégradé ne signalerait plus rien.
    final decoration = BoxDecoration(
      gradient: estompee ? null : PpColors.degradeMarque,
      color: estompee
          ? (sombre ? PpColors.bordureSombre : PpColors.bordureClaire)
          : null,
      borderRadius: BorderRadius.circular(PpRadius.md),
    );

    final couleurTexte = estompee
        ? theme.colorScheme.onSurfaceVariant
        : Colors.white;

    return Semantics(
      label: valeur == null
          ? 'Date à définir'
          : 'Le ${_jour.format(valeur)} ${_mois.format(valeur)}',
      excludeSemantics: true,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(
          vertical: PpSpacing.sm,
          horizontal: PpSpacing.xs,
        ),
        decoration: decoration,
        child: valeur == null
            ? _SansDate(couleur: couleurTexte)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _jour.format(valeur),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: couleurTexte,
                      fontWeight: FontWeight.w700,
                      fontFeatures: PpTypography.chiffresTabulaires,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mois.format(valeur),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: couleurTexte.withValues(alpha: 0.9),
                    ),
                  ),
                  if (avecHeure) ...[
                    const SizedBox(height: PpSpacing.xs),
                    Text(
                      _heure.format(valeur),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: couleurTexte.withValues(alpha: 0.9),
                        fontFeatures: PpTypography.chiffresTabulaires,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Pastille d'un événement dont le jour reste à choisir.
class _SansDate extends StatelessWidget {
  const _SansDate({required this.couleur});

  final Color couleur;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.calendar_today_rounded, size: 20, color: couleur),
      const SizedBox(height: PpSpacing.xs),
      Text(
        'À définir',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: couleur.withValues(alpha: 0.95),
          height: 1.1,
        ),
      ),
    ],
  );
}
