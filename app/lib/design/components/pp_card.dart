import 'package:flutter/material.dart';

import '../tokens.dart';

/// Carte du produit. Rayon généreux, bordure fine, ombre unique.
class PpCard extends StatelessWidget {
  const PpCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(PpSpacing.lg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(PpRadius.card),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: PpElevation.carte(sombre),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PpRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PpRadius.card),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Étiquette courte en majuscules, au-dessus d'un titre ou d'un chiffre clé.
class PpEyebrow extends StatelessWidget {
  const PpEyebrow(this.texte, {this.couleur, super.key});

  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Text(
    texte.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: couleur),
  );
}
