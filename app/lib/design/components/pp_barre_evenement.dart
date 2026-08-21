import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../tokens.dart';
import '../../app/router.dart';
import 'pp_barre_app.dart';
import 'pp_retour.dart';

/// Barre d'un écran rattaché à un événement.
///
/// Le titre porte le nom de la soirée, et la seconde ligne la section ouverte avec
/// l'état des présences. « Sondages » seul ne dirait pas de quelle soirée il s'agit :
/// on peut être membre de plusieurs, et l'écran serait le même pour toutes.
///
/// C'est la même disposition que la coquille d'événement, pour qu'entrer dans un écran
/// annexe ne donne pas l'impression de changer d'application.
class PpBarreEvenement extends ConsumerWidget implements PreferredSizeWidget {
  const PpBarreEvenement({
    required this.evenementId,
    required this.section,
    super.key,
  });

  final String evenementId;

  /// Nom de la section, en capitales : SONDAGES, ÉPINGLÉ, QUI REND QUOI.
  final String section;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evenement = ref.watch(evenementProvider(evenementId)).value;

    return PpBarreApp(
      bouton: PpRetour(versParent: PpRoutes.versEvenement(evenementId)),
      titre: Text(evenement?.nom ?? section),
      basDeBarre: _Contexte(
        section: section,
        membres: evenement?.nombreMembres,
        presents: evenement?.nombrePresents,
      ),
    );
  }
}

class _Contexte extends StatelessWidget implements PreferredSizeWidget {
  const _Contexte({
    required this.section,
    required this.membres,
    required this.presents,
  });

  final String section;
  final int? membres;
  final int? presents;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: PpSpacing.lg,
        right: PpSpacing.lg,
        bottom: PpSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            section,
            style: theme.textTheme.labelSmall?.copyWith(
              color: PpColors.violet,
              letterSpacing: 1.2,
            ),
          ),
          if (membres != null && presents != null) ...[
            const SizedBox(width: PpSpacing.sm),
            Text('·', style: theme.textTheme.labelSmall),
            const SizedBox(width: PpSpacing.sm),
            Text(
              '$presents présents sur $membres',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
