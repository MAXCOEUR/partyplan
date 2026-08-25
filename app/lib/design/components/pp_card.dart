import 'package:flutter/material.dart';

import '../tokens.dart';

/// Carte du produit.
///
/// Deux traitements selon le thème, et non un seul décliné. En clair, une carte blanche
/// posée sur un fond gris pâle avec une ombre douce : pas de bordure, parce qu'un liseré
/// gris sur chaque carte, empilé trois ou quatre fois par écran, donne une pile de boîtes
/// de formulaire. En sombre, une surface plus claire que le fond et un liseré fin, parce
/// qu'une ombre noire sur fond presque noir ne se voit pas.
class PpCard extends StatefulWidget {
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
  State<PpCard> createState() => _PpCardState();
}

class _PpCardState extends State<PpCard> {
  bool _enfoncee = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final interactive = widget.onTap != null;

    // Le retour au toucher est un enfoncement léger, jamais un rebond : une carte qui
    // rebondit à chaque appui devient fatigante sur un écran qu'on parcourt.
    final echelle = _enfoncee && interactive ? 0.985 : 1.0;

    final carte = DecoratedBox(
      decoration: BoxDecoration(
        color: sombre
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PpRadius.card),
        border: sombre
            ? Border.all(color: theme.colorScheme.outline)
            : null,
        boxShadow: PpElevation.carte(sombre),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PpRadius.card),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: interactive
              ? (enfoncee) => setState(() => _enfoncee = enfoncee)
              : null,
          borderRadius: BorderRadius.circular(PpRadius.card),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!interactive) {
      return carte;
    }

    return AnimatedScale(
      scale: echelle,
      duration: PpDuration.rapide,
      curve: Curves.easeOut,
      child: carte,
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
