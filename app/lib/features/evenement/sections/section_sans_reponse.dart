import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/membre.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';

/// Membres qui n'ont pas répondu, pour qui peut gérer l'événement.
///
/// C'est l'information la plus actionnable avant la soirée tant que les courses
/// n'existent pas (RG-UI-02) : relancer ceux qui n'ont rien dit.
class SectionSansReponse extends ConsumerWidget {
  const SectionSansReponse({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moi = ref.watch(monMembreProvider(evenementId)).value;
    final membres = ref.watch(membresProvider(evenementId)).value;

    if (moi == null || !moi.role.peutGerer || membres == null) {
      return const SizedBox.shrink();
    }

    final sansReponse = membres
        .where((m) => m.statut == StatutPresence.inconnu)
        .length;

    if (sansReponse == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        onTap: () => context.push(PpRoutes.versInvites(evenementId)),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: PpColors.orange),
            const SizedBox(width: PpSpacing.md),
            Expanded(
              child: Text(
                PpL10n.of(context).tdbSansReponse(sansReponse),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
