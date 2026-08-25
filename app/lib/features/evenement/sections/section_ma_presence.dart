import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/membre.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/components/pp_optimistic.dart';
import '../../../design/components/pp_status_chip.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';
import '../presence_vers_pastille.dart';

/// Ma réponse à l'invitation (EF-PRES-03).
///
/// RG-PRES-01 — le statut initial est `Unknown`, jamais présumé présent. Tant que la
/// personne n'a pas répondu, la section pose la question ; ensuite elle se contente
/// d'offrir la modification.
class SectionMaPresence extends ConsumerWidget {
  const SectionMaPresence({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final moi = ref.watch(monMembreProvider(evenementId)).value;

    if (moi == null) {
      return const SizedBox.shrink();
    }

    final sansReponse = moi.statut == StatutPresence.inconnu;

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sansReponse
                  ? l10n.tdbMaPresenceQuestion
                  : l10n.tdbMaPresenceModifier,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: PpSpacing.md),
            Wrap(
              spacing: PpSpacing.sm,
              runSpacing: PpSpacing.sm,
              children: [
                for (final statut in _proposes)
                  _Choix(
                    statut: statut,
                    choisi: statut == moi.statut,
                    onChoisir: () => _repondre(context, ref, statut),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Les cinq statuts de EF-PRES-01. `inconnu` n'est pas proposé : c'est l'absence de
  /// réponse, pas une réponse.
  static const _proposes = [
    StatutPresence.present,
    StatutPresence.peutEtre,
    StatutPresence.absent,
    StatutPresence.enRetard,
    StatutPresence.partAvant,
  ];

  Future<void> _repondre(
    BuildContext context,
    WidgetRef ref,
    StatutPresence statut,
  ) async {
    final l10n = PpL10n.of(context);

    await PpOptimisticAction.executer(
      context: context,
      appliquer: () {},
      annuler: () => ref.invalidate(membresProvider(evenementId)),
      messageEchec: l10n.invitesEchecStatut,
      messageDiffere: l10n.horsLigneDiffere,
      envoyer: () async {
        await ref
            .read(evenementsApiProvider)
            .majMaPresence(evenementId, statut: statut);

        ref
          ..invalidate(membresProvider(evenementId))
          ..invalidate(evenementProvider(evenementId))
          ..invalidate(mesEvenementsProvider);
      },
    );
  }
}

class _Choix extends StatelessWidget {
  const _Choix({
    required this.statut,
    required this.choisi,
    required this.onChoisir,
  });

  final StatutPresence statut;
  final bool choisi;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('statut-${statut.versApi}'),
    onTap: onChoisir,
    borderRadius: BorderRadius.circular(PpRadius.pill),
    // Pas d'`alignment` : il ferait occuper à la boîte toute la largeur disponible,
    // et la pastille sélectionnée s'étirerait sur la ligne entière.
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.all(PpSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(
          color: choisi ? PpColors.violet : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(PpRadius.pill),
      ),
      // Neutre tant que ce n'est pas la réponse retenue. Cinq couleurs pour cinq
      // options mettaient cinq accents sur l'écran, et la réponse choisie ne se
      // distinguait plus que par un anneau qu'il fallait chercher.
      child: PpStatusChip(presence: versPastille(statut), neutre: !choisi),
    ),
  );
}
