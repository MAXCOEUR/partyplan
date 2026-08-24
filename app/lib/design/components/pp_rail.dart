import 'package:flutter/material.dart';

import '../tokens.dart';

/// Pose le contenu dans une colonne centrée, de largeur bornée.
///
/// Sur téléphone, le rail est transparent : le contenu occupe toute la largeur, comme
/// attendu. Sur navigateur ou tablette, il empêche l'interface de s'étirer — une liste
/// large de 1280 px place le libellé d'un article à gauche et son bouton d'attribution
/// à l'autre bout, et l'œil ne fait plus le lien.
///
/// Un seul composant pour toute l'application : une contrainte recopiée écran par
/// écran finirait par différer de l'un à l'autre.
class PpRail extends StatelessWidget {
  const PpRail({required this.child, this.largeur, super.key});

  final Widget child;

  /// Largeur maximale. Par défaut [PpBreakpoints.railContenu].
  final double? largeur;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: largeur ?? PpBreakpoints.railContenu,
      ),
      child: child,
    ),
  );
}

/// Place le bouton d'action flottant sur le bord droit du rail de contenu.
///
/// Le bouton par défaut se colle à l'angle de l'écran : sur un large écran, il se
/// retrouve loin de la liste sur laquelle il agit, dans une zone vide. Ici il suit le
/// contenu, quelle que soit la largeur.
class PpFabDansLeRail extends FloatingActionButtonLocation {
  const PpFabDansLeRail();

  static const _marge = PpSpacing.lg;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final largeurEcran = geometry.scaffoldSize.width;
    final largeurRail = largeurEcran > PpBreakpoints.railContenu
        ? PpBreakpoints.railContenu
        : largeurEcran;
    final bordDroitDuRail = (largeurEcran + largeurRail) / 2;
    final positionStandard = FloatingActionButtonLocation.endFloat.getOffset(
      geometry,
    );

    final x =
        bordDroitDuRail - geometry.floatingActionButtonSize.width - _marge;

    // Flutter tient déjà compte ici de la barre basse, du clavier, des SnackBars et
    // des feuilles. Seul l'alignement horizontal est spécifique au rail PartyPlan.
    return Offset(x, positionStandard.dy);
  }

  @override
  String toString() => 'PpFabDansLeRail';
}
