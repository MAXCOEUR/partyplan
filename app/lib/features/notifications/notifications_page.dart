import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/models/avis.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_skeleton.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Notifications reçues (`§5.12`).
///
/// **Une liste sur laquelle on agit**, à l'inverse du fil d'activité : on ouvre, on
/// marque lu. Elle emploie donc des `PpCard`, là où le fil n'en a aucune. La distinction
/// posée au lot 1.10 doit rester lisible d'un écran à l'autre : ce qui se touche est une
/// carte, ce qui se lit ne l'est pas.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final avis = ref.watch(avisProvider);

    return Scaffold(
      appBar: PpBarreApp(
        titre: Text(l10n.avisTitre),
        actions: [
          if (avis.value?.nonLus case final nonLus? when nonLus > 0)
            TextButton(
              onPressed: () async {
                await ref.read(avisApiProvider).toutMarquerLu();
                ref.invalidate(avisProvider);
              },
              child: Text(l10n.avisToutMarquerLu),
            ),
        ],
      ),
      body: PpRail(
        child: avis.when(
          loading: () => const _SqueletteAvis(),
          error: (_, _) => PpErrorState(
            message: l10n.avisErreurTitre,
            onRetry: () => ref.invalidate(avisProvider),
          ),
          data: (page) => page.avis.isEmpty
              ? PpEmptyState(
                  titre: l10n.avisVideTitre,
                  explication: l10n.avisVideExplication,
                  icone: Icons.notifications_none_rounded,
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(avisProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PpSpacing.lg,
                      vertical: PpSpacing.md,
                    ),
                    itemCount: page.avis.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: PpSpacing.sm),
                      child: _LigneAvis(avis: page.avis[index]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LigneAvis extends ConsumerWidget {
  const _LigneAvis({required this.avis});

  final Avis avis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    final secondaire = sombre
        ? PpColors.texteSecondaireSombre
        : PpColors.texteSecondaireClair;

    return PpCard(
      onTap: () async {
        // Marqué lu avant d'ouvrir : partir sur une autre route d'abord laisserait la
        // pastille pleine au retour, et donnerait le sentiment que rien n'a été pris en
        // compte.
        if (!avis.lu) {
          await ref.read(avisApiProvider).marquerLu(avis.id);
          ref.invalidate(avisProvider);
        }

        if (avis.lienProfond case final lien? when context.mounted) {
          context.push(lien);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le point de non-lu, et rien d'autre : une couleur de fond différente
          // rendrait la liste bariolée dès qu'il en reste trois.
          Padding(
            padding: const EdgeInsets.only(top: 6, right: PpSpacing.md),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avis.lu ? Colors.transparent : theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avis.titre,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: avis.lu ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(avis.corps, style: theme.textTheme.bodyMedium),
                const SizedBox(height: PpSpacing.xs),
                Text(
                  ilYA(avis.recuLe),
                  style: theme.textTheme.labelSmall?.copyWith(color: secondaire),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SqueletteAvis extends StatelessWidget {
  const _SqueletteAvis();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.symmetric(
      horizontal: PpSpacing.lg,
      vertical: PpSpacing.md,
    ),
    itemCount: 5,
    itemBuilder: (context, index) => const Padding(
      padding: EdgeInsets.only(bottom: PpSpacing.sm),
      child: PpCardSquelette(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PpSkeleton.ligne(largeur: 180),
            SizedBox(height: PpSpacing.sm),
            PpSkeleton.ligne(largeur: 240, hauteur: 12),
          ],
        ),
      ),
    ),
  );
}
