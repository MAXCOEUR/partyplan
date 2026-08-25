import 'package:flutter/material.dart';

import '../tokens.dart';

/// Bloc de squelette : une forme neutre à la place d'un contenu qui arrive.
///
/// Un squelette n'est pas un spinner déguisé. Il tient sa valeur d'une seule chose :
/// **occuper la place exacte du contenu réel**, pour que rien ne saute quand la donnée
/// arrive. Un squelette qui ne ressemble pas à ce qui va s'afficher est pire qu'un
/// indicateur honnête — c'est ce que disait le commentaire d'origine de `PpLoadingState`,
/// et il avait raison tant que les écrans n'existaient pas. Ils existent.
///
/// **Note pour les tests** : le balayage boucle indéfiniment. Un `pumpAndSettle` sur un
/// écran affichant un squelette n'aboutirait jamais. Utiliser `pump(durée)` dans ce cas,
/// ou pomper jusqu'à l'arrivée de la donnée.
class PpSkeleton extends StatefulWidget {
  const PpSkeleton({
    required this.largeur,
    required this.hauteur,
    this.rayon = PpRadius.sm,
    super.key,
  });

  /// Barre de texte. La largeur est relative, le texte n'ayant pas de largeur fixe.
  const PpSkeleton.ligne({
    required this.largeur,
    this.hauteur = 14,
    this.rayon = PpRadius.sm,
    super.key,
  });

  const PpSkeleton.cercle({required double diametre, super.key})
    : largeur = diametre,
      hauteur = diametre,
      rayon = PpRadius.pill;

  final double largeur;
  final double hauteur;
  final double rayon;

  @override
  State<PpSkeleton> createState() => _PpSkeletonState();
}

class _PpSkeletonState extends State<PpSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // Le démarrage n'a pas sa place dans initState : la décision dépend de MediaQuery, et
  // lire un widget hérité avant la fin de initState est interdit. C'est
  // didChangeDependencies qui décide, appelée une première fois avant le premier build
  // puis à chaque changement du réglage.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Un balayage perpétuel est exactement ce que le réglage « réduire les animations »
    // cherche à faire taire.
    final desactivees = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (desactivees && _controleur.isAnimating) {
      _controleur.stop();
    } else if (!desactivees && !_controleur.isAnimating) {
      _controleur.repeat();
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final base = schema.surfaceContainerHigh;
    final crete = schema.surfaceContainerHighest;

    return SizedBox(
      width: widget.largeur,
      height: widget.hauteur,
      child: AnimatedBuilder(
        animation: _controleur,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.rayon),
            // Un balayage et non un clignotement : le clignotement attire l'œil sur le
            // vide, le balayage suggère un chargement en cours.
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - _controleur.value), 0),
              end: Alignment(1 + 2 * _controleur.value, 0),
              colors: [base, crete, base],
            ),
          ),
        ),
      ),
    );
  }
}

/// Squelette d'une liste de cartes : la forme la plus fréquente du produit.
///
/// Trois lignes par carte, comme une carte réelle en porte : un titre, une précision,
/// une valeur. Le nombre de cartes est volontairement bas — trois suffisent à occuper
/// un écran de téléphone, et remplir la page de faux contenu ne rend pas l'attente
/// plus courte.
class PpSkeletonListe extends StatelessWidget {
  const PpSkeletonListe({this.cartes = 3, super.key});

  final int cartes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(PpSpacing.lg),
    // Une Column et non un ListView : ce squelette est posé aussi bien en corps d'écran
    // que dans une Column existante, et un ListView y lèverait une erreur de hauteur non
    // bornée. Avec `min`, il occupe la place de son contenu et se compose partout.
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cartes; i++) ...[
          if (i > 0) const SizedBox(height: PpSpacing.md),
          const _CarteSquelette(),
        ],
      ],
    ),
  );
}

class _CarteSquelette extends StatelessWidget {
  const _CarteSquelette();

  @override
  Widget build(BuildContext context) => PpCardSquelette(
    child: Row(
      children: [
        const PpSkeleton.cercle(diametre: 44),
        const SizedBox(width: PpSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PpSkeleton.ligne(largeur: 140, hauteur: 15),
              const SizedBox(height: PpSpacing.sm),
              const PpSkeleton.ligne(largeur: 90, hauteur: 12),
            ],
          ),
        ),
        const SizedBox(width: PpSpacing.md),
        const PpSkeleton.ligne(largeur: 56, hauteur: 18),
      ],
    ),
  );
}

/// Enveloppe d'une carte de squelette, aux mêmes formes qu'une carte réelle.
///
/// Séparée de `PpCard` volontairement : une carte de squelette n'est jamais cliquable,
/// et lui donner un retour au toucher inviterait à appuyer sur du vide.
class PpCardSquelette extends StatelessWidget {
  const PpCardSquelette({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sombre
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(PpRadius.card),
        border: sombre ? Border.all(color: theme.colorScheme.outline) : null,
        boxShadow: PpElevation.carte(sombre),
      ),
      child: Padding(padding: const EdgeInsets.all(PpSpacing.lg), child: child),
    );
  }
}
