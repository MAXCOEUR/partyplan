import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tokens.dart';
import '../typography.dart';

/// Sens d'un montant, du point de vue de la personne qui regarde.
enum PpMoneySense {
  /// Information neutre : total dépensé, prix d'un article.
  neutre,

  /// On doit de l'argent à la personne qui regarde.
  crediteur,

  /// La personne qui regarde doit de l'argent.
  debiteur,
}

/// Affichage d'un montant en euros.
///
/// L'argent est le sujet central de PartyPlan : il ne peut pas être rendu par un `Text`
/// ordinaire. Trois partis pris :
///
/// * chiffres à largeur fixe, pour qu'une colonne de sommes s'aligne réellement ;
/// * centimes en retrait typographique, l'euro se lisant d'abord ;
/// * couleur porteuse de sens plutôt que décorative — vert quand on vous doit, rose
///   quand vous devez. Un utilisateur doit savoir de quel côté il est sans lire de
///   libellé.
class PpMoney extends StatelessWidget {
  const PpMoney(
    this.montant, {
    this.sense = PpMoneySense.neutre,
    this.style,
    this.afficherSigne = false,
    super.key,
  });

  final double montant;
  final PpMoneySense sense;
  final TextStyle? style;

  /// Préfixe explicite « + » ou « − ». Réservé aux écrans de soldes, où le signe
  /// porte une information ; ailleurs il ajoute du bruit.
  final bool afficherSigne;

  static final NumberFormat _entier = NumberFormat('#,##0', 'fr_FR');

  /// Espace insécable avant le symbole monétaire, comme l'exige la typographie
  /// française. Une espace ordinaire laisserait le « € » passer seul à la ligne.
  static const espaceInsecable = '\u00A0';

  /// Le même montant, en texte.
  ///
  /// Exposé parce que le fil d'activité compose des phrases : « a acheté Glaçons pour
  /// 4,50 € ». Écrire un second formateur ailleurs le ferait diverger de celui-ci au
  /// premier ajustement, et deux mises en forme de montant dans la même application se
  /// remarquent.
  static String enTexte(double montant) {
    final valeurAbsolue = montant.abs();
    final centimes = ((valeurAbsolue * 100).round() % 100)
        .toString()
        .padLeft(2, '0');
    final euros = _entier.format(valeurAbsolue.truncate());

    return '$euros,$centimes$espaceInsecable€';
  }

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.titleLarge)!.copyWith(
      fontFeatures: PpTypography.chiffresTabulaires,
      color: _couleur(context),
      fontWeight: FontWeight.w600,
    );

    final valeurAbsolue = montant.abs();
    final centimes = ((valeurAbsolue * 100).round() % 100).toString().padLeft(
      2,
      '0',
    );
    final euros = _entier.format(valeurAbsolue.truncate());
    final signe = !afficherSigne
        ? ''
        : montant < 0
        ? '−'
        : '+';

    return Semantics(
      label: _libelleAccessible(valeurAbsolue, centimes),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$signe$euros', style: base),
            TextSpan(
              text: ',$centimes',
              style: base.copyWith(fontSize: (base.fontSize ?? 20) * 0.72),
            ),
            TextSpan(
              text: '$espaceInsecable€',
              style: base.copyWith(fontSize: (base.fontSize ?? 20) * 0.72),
            ),
          ],
        ),
      ),
    );
  }

  Color _couleur(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return switch (sense) {
      PpMoneySense.neutre => Theme.of(context).colorScheme.onSurface,
      PpMoneySense.crediteur => PpColors.texteSur(PpColors.vert, brightness),
      PpMoneySense.debiteur => PpColors.texteSur(PpColors.rose, brightness),
    };
  }

  /// Le lecteur d'écran entend une phrase, pas un assemblage de fragments (NF-A11Y-03).
  String _libelleAccessible(double valeurAbsolue, String centimes) {
    final montantLu =
        '${_entier.format(valeurAbsolue.truncate())} euros $centimes';

    return switch (sense) {
      PpMoneySense.neutre => montantLu,
      PpMoneySense.crediteur => 'On vous doit $montantLu',
      PpMoneySense.debiteur => 'Vous devez $montantLu',
    };
  }
}
