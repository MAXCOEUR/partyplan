import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pp_rail.dart';

/// Barre d'application alignée sur le rail de contenu.
///
/// Une barre pleine largeur dont le titre est collé au bord gauche, au-dessus d'un
/// contenu centré qui commence au tiers de l'écran, donne l'impression de deux mises en
/// page superposées. Ici le titre et les actions se posent sur les mêmes bords que les
/// cartes qu'ils coiffent.
///
/// Sur téléphone, le rail occupe toute la largeur : la barre se comporte comme une
/// `AppBar` ordinaire.
class PpBarreApp extends StatelessWidget implements PreferredSizeWidget {
  const PpBarreApp({
    required this.titre,
    this.actions = const [],
    this.basDeBarre,
    this.bouton,
    super.key,
  });

  final Widget titre;
  final List<Widget> actions;

  /// Deuxième ligne, sous le titre.
  final PreferredSizeWidget? basDeBarre;

  /// Bouton de retour ou autre commande précédant le titre.
  final Widget? bouton;

  static const _hauteurBarre = kToolbarHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(_hauteurBarre + (basDeBarre?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: _hauteurBarre,
              child: PpRail(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PpSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      ?bouton,
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: theme.appBarTheme.titleTextStyle ??
                              theme.textTheme.titleLarge!,
                          overflow: TextOverflow.ellipsis,
                          child: titre,
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
            ),
            if (basDeBarre != null) PpRail(child: basDeBarre!),
          ],
        ),
      ),
    );
  }
}
