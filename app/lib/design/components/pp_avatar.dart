import 'package:flutter/material.dart';

import '../tokens.dart';

/// Avatar d'une personne.
///
/// À défaut de photo, les initiales sur une couleur dérivée du nom. Généré localement,
/// sans appel à un service externe de type Gravatar (RG-USR-02) : une adresse e-mail
/// envoyée à un tiers pour obtenir une image serait une fuite inutile.
class PpAvatar extends StatelessWidget {
  const PpAvatar({
    required this.nom,
    this.urlPhoto,
    this.taille = 40,
    super.key,
  });

  final String nom;
  final String? urlPhoto;
  final double taille;

  /// Teintes de la charte, réservées aux avatars. La couleur est stable pour un même
  /// nom : une personne garde son repère visuel d'un écran à l'autre.
  static const _teintes = [
    PpColors.violet,
    PpColors.violetClair,
    PpColors.rose,
    PpColors.vert,
    PpColors.orange,
    PpColors.bleu,
  ];

  static String initiales(String nom) {
    final morceaux = nom
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .toList();

    if (morceaux.isEmpty) {
      return '?';
    }

    if (morceaux.length == 1) {
      return morceaux.first.characters.first.toUpperCase();
    }

    return (morceaux.first.characters.first + morceaux.last.characters.first)
        .toUpperCase();
  }

  static Color couleurPour(String nom) {
    var somme = 0;
    for (final unite in nom.codeUnits) {
      somme = (somme + unite) % 4096;
    }
    return _teintes[somme % _teintes.length];
  }

  @override
  Widget build(BuildContext context) {
    final fond = couleurPour(nom);

    return Semantics(
      label: nom,
      excludeSemantics: true,
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          color: fond,
          shape: BoxShape.circle,
          image: urlPhoto == null
              ? null
              : DecorationImage(
                  image: NetworkImage(urlPhoto!),
                  fit: BoxFit.cover,
                ),
        ),
        alignment: Alignment.center,
        child: urlPhoto != null
            ? null
            : Text(
                initiales(nom),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: taille * 0.38,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}

/// Pile d'avatars avec compteur de débordement. Montre qui vient sans occuper la
/// largeur d'une liste nominative.
class PpAvatarStack extends StatelessWidget {
  const PpAvatarStack({
    required this.noms,
    this.maximum = 4,
    this.taille = 32,
    super.key,
  });

  final List<String> noms;
  final int maximum;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final visibles = noms.take(maximum).toList();
    final reste = noms.length - visibles.length;
    final decalage = taille * 0.68;
    final theme = Theme.of(context);

    return Semantics(
      label: noms.isEmpty ? 'Aucun participant' : '${noms.length} participants',
      excludeSemantics: true,
      child: SizedBox(
        height: taille,
        width: visibles.isEmpty
            ? 0
            : decalage * visibles.length +
                  (reste > 0 ? decalage : 0) +
                  taille * 0.32,
        child: Stack(
          children: [
            for (var i = 0; i < visibles.length; i++)
              Positioned(
                left: i * decalage,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: PpAvatar(nom: visibles[i], taille: taille),
                ),
              ),
            if (reste > 0)
              Positioned(
                left: visibles.length * decalage,
                child: Container(
                  width: taille,
                  height: taille,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$reste',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: taille * 0.34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
