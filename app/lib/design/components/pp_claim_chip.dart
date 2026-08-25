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
    this.onPressed,
    this.enCours = false,
    super.key,
  });

  /// Texte affiché lorsque personne ne s'en occupe, par exemple « À prendre ».
  final String libelleLibre;

  /// Nom de la personne qui s'en occupe. Nul si l'article est libre.
  final String? nomAttributaire;

  final VoidCallback? onPressed;

  /// Écriture optimiste en attente de confirmation du serveur (RG-UI-03).
  final bool enCours;

  bool get _estPris => nomAttributaire != null;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // À l'état libre, le libellé est du texte sur fond clair : il lui faut la variante
    // accessible. À l'état pris, c'est du blanc sur un aplat, d'où un rose assombri.
    final couleurTexte = _estPris
        ? Theme.of(context).colorScheme.onSecondary
        : PpColors.texteSur(PpColors.rose, brightness);

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
              left: _estPris ? PpSpacing.xs : PpSpacing.lg,
              right: PpSpacing.lg,
              top: PpSpacing.xs,
              bottom: PpSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _estPris
                  ? PpColors.rose
                  : PpColors.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(PpRadius.pill),
              border: _estPris
                  ? null
                  : Border.all(color: couleurTexte.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_estPris) ...[
                  PpAvatar(nom: nomAttributaire!, taille: 32),
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
