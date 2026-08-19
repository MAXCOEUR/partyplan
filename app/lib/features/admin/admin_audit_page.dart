import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/profil.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';

final journalAuditProvider = FutureProvider<List<EntreeAudit>>(
  (ref) => ref.watch(comptesApiProvider).journalAudit(taille: 100),
);

/// Journal d'audit (EF-ADM-09).
///
/// En lecture seule, sans aucune action : la table est en ajout seul, et la base refuse
/// toute modification ou suppression, y compris à un administrateur (RG-ADM-06,
/// NF-SEC-08). L'absence de bouton n'est pas un oubli.
class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  static final _horodatage = DateFormat('dd/MM/yyyy à HH:mm:ss', 'fr_FR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalAuditProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal d’audit')),
      body: journal.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: PpStrings.erreurReseau,
          onRetry: () => ref.invalidate(journalAuditProvider),
        ),
        data: (entrees) => entrees.isEmpty
            ? const PpEmptyState(
                titre: 'Journal vide',
                explication:
                    'Aucune action d’administration n’a encore été enregistrée.',
                icone: Icons.history_rounded,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(journalAuditProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PpSpacing.lg),
                  itemCount: entrees.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PpSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: PpSpacing.sm),
                        child: Text(
                          'Trace inaltérable de toutes les actions d’administration. '
                          'Ni modification ni suppression ne sont possibles.',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }

                    return _LigneAudit(
                      entree: entrees[index - 1],
                      horodatage: _horodatage,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _LigneAudit extends StatelessWidget {
  const _LigneAudit({required this.entree, required this.horodatage});

  final EntreeAudit entree;
  final DateFormat horodatage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icone, couleur) = _apparence(entree.action);

    return PpCard(
      padding: const EdgeInsets.all(PpSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PpRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icone,
              size: 18,
              color: PpColors.texteSur(couleur, theme.brightness),
            ),
          ),
          const SizedBox(width: PpSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entree.actionLisible, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Par ${entree.auteur} · ${horodatage.format(entree.creeLe.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
                if (entree.motif != null) ...[
                  const SizedBox(height: PpSpacing.xs),
                  Text(
                    'Motif : ${entree.motif}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
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

  static (IconData, Color) _apparence(String action) => switch (action) {
    'admin.seeded' => (Icons.rocket_launch_rounded, PpColors.violet),
    'user.password_reset_triggered' => (
      Icons.lock_reset_rounded,
      PpColors.bleu,
    ),
    'user.sessions_revoked' => (Icons.logout_rounded, PpColors.bleu),
    'user.suspended' => (Icons.pause_rounded, PpColors.orange),
    'user.unsuspended' => (Icons.play_arrow_rounded, PpColors.vert),
    'user.deleted' => (Icons.delete_forever_rounded, PpColors.rouge),
    'user.role_changed' => (Icons.badge_rounded, PpColors.violet),
    _ => (Icons.circle_outlined, PpColors.texteSecondaireClair),
  };
}
