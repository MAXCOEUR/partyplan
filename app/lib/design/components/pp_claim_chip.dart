import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pp_avatar.dart';

/// Pastille d'attribution d'un article de courses.
///
/// C'est l'interaction centrale du produit : « qui prend quoi ». Elle passe d'un
/// contour discontinu — personne ne s'en occupe, il reste quelque chose à faire — à un
/// aplat portant le visage de la personne. L'état de la liste se lit alors d'un coup
/// d'œil, sans lire une seule ligne de texte.
///
/// Voir EF-CRS-03 et RG-CRS-01 : un seul attributaire, contrôlé côté serveur.
class PpClaimChip extends StatelessWidget {
  const PpClaimChip({
    required this.libelleLibre,
    this.nomAttributaire,
    this.photoAttributaire,
    this.onPressed,
    this.enCours = false,
    super.key,
  });

  /// Texte affiché lorsque personne ne s'en occupe, par exemple « À prendre ».
  final String libelleLibre;

  /// Nom de la personne qui s'en occupe. Nul si l'article est libre.
  final String? nomAttributaire;

  /// Photo de l'attributaire, quand il en a une.
  final String? photoAttributaire;

  final VoidCallback? onPressed;

  /// Écriture optimiste en attente de confirmation du serveur (RG-UI-03).
  final bool enCours;

  bool get _estPris => nomAttributaire != null;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    // Deux registres, et non deux nuances du même. À l'état libre c'est une commande —
    // « je m'en occupe » — donc un contour qui appelle l'appui. À l'état pris c'est un
    // état, et un aplat plein en ferait l'élément le plus voyant de la ligne alors
    // qu'il porte l'information la moins importante : un fond teinté suffit, et laisse
    // le nom de l'article dominer.
    //
    // Le violet et non le rose : la charte réserve le rose à l'argent dû, et une prise
    // en charge n'est pas une dette.
    final couleurTexte = schema.primary;

    return Semantics(
      button: onPressed != null,
      label: _estPris
          ? '$nomAttributaire s’en occupe'
          : '$libelleLibre. Appuyer pour vous en occuper',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enCours ? null : onPressed,
          borderRadius: BorderRadius.circular(PpRadius.pill),
          child: AnimatedContainer(
            duration: PpDuration.normale,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: PpA11y.cibleMinimale),
            padding: EdgeInsets.only(
              left: _estPris ? PpSpacing.xs : PpSpacing.md,
              right: PpSpacing.md,
              top: PpSpacing.xs,
              bottom: PpSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: schema.primary.withValues(alpha: _estPris ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(PpRadius.pill),
              // Le contour n'apparaît qu'à l'état libre, celui où l'on attend un appui.
              border: _estPris
                  ? null
                  : Border.all(color: couleurTexte.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_estPris) ...[
                  PpAvatar(
                    nom: nomAttributaire!,
                    urlPhoto: photoAttributaire,
                    // 24 et non 32 : un avatar de 32 dans une pastille impose une
                    // hauteur qui écrase le reste de la ligne.
                    taille: 24,
                  ),
                  const SizedBox(width: PpSpacing.sm),
                ],
                if (enCours) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: couleurTexte,
                    ),
                  ),
                  const SizedBox(width: PpSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    _estPris ? nomAttributaire! : libelleLibre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: couleurTexte,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
