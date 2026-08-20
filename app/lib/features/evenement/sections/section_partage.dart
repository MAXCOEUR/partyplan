import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';

/// Invitation à partager le lien.
///
/// Visible uniquement pour qui peut gérer l'événement. La décision appartient à la
/// section, jamais à la page : sinon la page finirait par tout savoir de tous les
/// modules.
class SectionPartage extends ConsumerWidget {
  const SectionPartage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moi = ref.watch(monMembreProvider(evenementId)).value;

    if (moi == null || !moi.role.peutGerer) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        onTap: () => context.push(PpRoutes.versInvitation(evenementId)),
        child: Row(
          children: [
            const Icon(Icons.ios_share_rounded, color: PpColors.violet),
            const SizedBox(width: PpSpacing.md),
            Expanded(
              child: Text(
                PpL10n.of(context).tdbPartagerInvitation,
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
