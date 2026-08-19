import 'package:flutter/material.dart';

import '../tokens.dart';

/// Avancement d'une liste : courses prises, tâches faites.
///
/// Le libellé indique toujours « n / m » plutôt qu'un pourcentage. Devant une liste de
/// courses, on veut savoir combien d'articles restent, pas un taux.
class PpProgress extends StatelessWidget {
  const PpProgress({
    required this.fait,
    required this.total,
    this.couleur = PpColors.vert,
    this.libelle,
    super.key,
  });

  final int fait;
  final int total;
  final Color couleur;
  final String? libelle;

  double get ratio => total <= 0 ? 0 : (fait / total).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${libelle ?? 'Avancement'} : $fait sur $total',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (libelle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PpSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(libelle!, style: theme.textTheme.bodySmall),
                  Text(
                    '$fait / $total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(PpRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: PpDuration.lente,
              curve: Curves.easeOutCubic,
              builder: (context, valeur, _) => LinearProgressIndicator(
                value: valeur,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation(couleur),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
