import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';
import '../../activite/ligne_activite.dart';

/// Les dernières lignes du fil, sur le tableau de bord (`EF-FIL-01`).
///
/// C'est là que le fil sert le plus : on ouvre la soirée, et on voit ce qui a bougé
/// depuis la dernière fois. L'écran complet reste à un geste, pour le reste.
///
/// **La section disparaît entièrement** quand il n'y a rien à montrer — fil vide,
/// chargement, ou erreur. Le tableau de bord porte déjà plusieurs blocs : un bloc
/// « Activité » vide occuperait la place utile sans rien dire, un squelette de plus le
/// ferait clignoter à chaque ouverture, et l'échec d'un complément ne doit pas parasiter
/// un écran dont le reste s'affiche.
class SectionActivite extends ConsumerWidget {
  const SectionActivite({required this.evenementId, super.key});

  final String evenementId;

  /// Un résumé, pas le fil. Au-delà, la section prendrait la place des autres blocs.
  static const _lignesAffichees = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    final lignes = ref
        .watch(filActiviteProvider(evenementId))
        .maybeWhen(
          data: (page) => page.lignes.take(_lignesAffichees).toList(),
          orElse: () => const [],
        );

    if (lignes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.filTitre, style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () =>
                      context.push(PpRoutes.versActivite(evenementId)),
                  child: Text(l10n.filToutVoir),
                ),
              ],
            ),
            const SizedBox(height: PpSpacing.sm),
            for (final (rang, activite) in lignes.indexed)
              LigneActivite(
                activite: activite,
                rang: rang,
                // Pas de marqueur de jour dans un résumé de trois lignes : il
                // annoncerait une structure de registre là où il n'y a qu'un aperçu.
                debuteUnJour: false,
                premiere: rang == 0,
                // Le filet s'arrête sous la dernière : la suite est derrière
                // « Tout voir », pas plus bas dans la carte.
                derniere: rang == lignes.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}
