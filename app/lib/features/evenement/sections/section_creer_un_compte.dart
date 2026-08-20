import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';

/// Proposition de conversion en compte, pour un invité sans compte (EF-AUTH-11).
///
/// L'argument affiché est celui qui compte : sans compte, l'accès est lié à cet
/// appareil et à ce navigateur.
class SectionCreerUnCompte extends ConsumerWidget {
  const SectionCreerUnCompte({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(sessionProvider).value;

    if (etat != EtatSession.invite) {
      return const SizedBox.shrink();
    }

    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.conversionTitre, style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.xs),
            Text(l10n.conversionExplication, style: theme.textTheme.bodySmall),
            const SizedBox(height: PpSpacing.md),
            FilledButton(
              onPressed: () => context.push(PpRoutes.inscription),
              child: Text(l10n.conversionCreerUnCompte),
            ),
          ],
        ),
      ),
    );
  }
}
