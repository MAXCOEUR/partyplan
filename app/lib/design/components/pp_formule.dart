import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tokens.dart';

/// Formule d'un compte, telle qu'elle se lit (EF-PRM-05).
///
/// Un seul composant sert le profil, la fiche du back-office et l'accueil : la formule y
/// est la même information, et trois écritures séparées auraient fini par diverger sur le
/// libellé comme sur la couleur.
///
/// Aucune de ces surfaces ne propose d'abonnement. Il n'y a pas d'encaissement, et un
/// bouton d'achat sans caisse serait un bouton condamné — le produit s'interdit déjà
/// ceux-là pour la connexion Google.
class PpFormule extends StatelessWidget {
  const PpFormule({
    required this.premiumJusquau,
    this.evenementsPossedes,
    this.quotaEvenements,
    super.key,
  });

  /// Échéance de la formule payante, nulle ou passée en formule gratuite.
  final DateTime? premiumJusquau;

  /// Nombre d'événements à venir possédés. Affiche le quota consommé quand il est fourni
  /// et que le compte est gratuit.
  final int? evenementsPossedes;

  /// Plafond d'événements de la formule gratuite. Fourni par l'appelant plutôt que codé
  /// ici : le chiffre appartient au serveur, qui seul l'applique.
  final int? quotaEvenements;

  static final _echeance = DateFormat('dd/MM/yyyy', 'fr_FR');

  bool get _abonne {
    final terme = premiumJusquau;

    return terme != null && terme.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abonne = _abonne;

    // L'accent vient du thème et non d'une couleur nommée : la formule doit suivre
    // l'identité en clair comme en sombre, sans second réglage à tenir à jour.
    final couleur = abonne
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    final libelle = abonne
        ? 'Premium jusqu\'au ${_echeance.format(premiumJusquau!.toLocal())}'
        : 'Gratuit';

    final possedes = evenementsPossedes;
    final quota = quotaEvenements;
    final detail = !abonne && possedes != null && quota != null
        ? possedes <= 1
            ? '$possedes soirée sur $quota'
            : '$possedes soirées sur $quota'
        : null;

    return Semantics(
      label: detail == null ? 'Formule $libelle' : 'Formule $libelle, $detail',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            abonne ? Icons.workspace_premium_outlined : Icons.person_outline,
            size: 20,
            color: couleur,
          ),
          const SizedBox(width: PpSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: couleur,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: PpSpacing.xs),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
