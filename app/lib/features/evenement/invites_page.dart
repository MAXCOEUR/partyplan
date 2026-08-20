import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/membre.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_optimistic.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_status_chip.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import 'presence_vers_pastille.dart';

/// Liste des invités et de leurs présences (EF-PRES-04 à EF-PRES-06).
class InvitesPage extends ConsumerWidget {
  const InvitesPage({
    required this.evenementId,
    this.dansUneCoquille = false,
    super.key,
  });

  final String evenementId;

  /// Quand la page est affichée dans la coquille d'événement, elle n'a pas sa propre
  /// barre : la coquille la fournit déjà.
  final bool dansUneCoquille;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final membres = ref.watch(membresProvider(evenementId));

    final corps = membres.when(
      loading: () => const PpLoadingState(),
      error: (_, _) => PpErrorState(
        message: l10n.invitesErreur,
        onRetry: () => ref.invalidate(membresProvider(evenementId)),
      ),
      data: (liste) => _Liste(
        evenementId: evenementId,
        membres: liste,
        onRafraichir: () => ref.invalidate(membresProvider(evenementId)),
      ),
    );

    if (dansUneCoquille) {
      return corps;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.invitesTitre)),
      body: corps,
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({
    required this.evenementId,
    required this.membres,
    required this.onRafraichir,
  });

  final String evenementId;
  final List<Membre> membres;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    // RG-PRES-02 : « arrive plus tard » et « part plus tôt » comptent comme présents.
    // RG-PRES-03 : « peut-être » est compté à part, jamais avec les présents.
    final presents = membres.where((m) => m.statut.compteCommePresent).length;
    final peutEtre = membres
        .where((m) => m.statut == StatutPresence.peutEtre)
        .length;
    // RG-PRES-04 : les têtes sont un décompte distinct des présents.
    final tetes = membres.fold(0, (total, m) => total + m.tetes);

    final moi = membres.where((m) => m.cestMoi).firstOrNull;

    return RefreshIndicator(
      onRefresh: () async => onRafraichir(),
      child: ListView(
        padding: const EdgeInsets.all(PpSpacing.lg),
        children: [
          PpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.presencesSurInvites(presents, membres.length),
                  style: theme.textTheme.titleMedium,
                ),
                if (peutEtre > 0)
                  Text(
                    l10n.peutEtreSuffixe(peutEtre),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PpColors.orangeTexte,
                    ),
                  ),
                if (tetes != presents) ...[
                  const SizedBox(height: PpSpacing.xs),
                  Text(
                    l10n.tetesAPrevoir(tetes),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PpSpacing.lg),
          for (final membre in membres)
            _CarteMembre(
              evenementId: evenementId,
              membre: membre,
              monRole: moi?.role ?? RoleMembre.membre,
            ),
        ],
      ),
    );
  }
}

class _CarteMembre extends ConsumerWidget {
  const _CarteMembre({
    required this.evenementId,
    required this.membre,
    required this.monRole,
  });

  final String evenementId;
  final Membre membre;
  final RoleMembre monRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    // RG-ROLE-01 : le propriétaire ne peut pas être exclu. Et personne ne s'exclut
    // soi-même : pour partir, on quitte l'événement.
    final peutExclure =
        monRole.peutGerer &&
        !membre.cestMoi &&
        membre.role != RoleMembre.proprietaire;

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PpAvatar(nom: membre.nomAffiche, urlPhoto: membre.avatarUrl),
                const SizedBox(width: PpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membre.nomAffiche,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (membre.role != RoleMembre.membre)
                        PpEyebrow(
                          membre.role == RoleMembre.proprietaire
                              ? l10n.roleProprietaire
                              : l10n.roleAdministrateur,
                          couleur: PpColors.violet,
                        ),
                    ],
                  ),
                ),
                if (peutExclure)
                  IconButton(
                    key: ValueKey('exclure-${membre.id}'),
                    tooltip: l10n.invitesExclure,
                    onPressed: () => _confirmerExclusion(context, ref),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
              ],
            ),
            const SizedBox(height: PpSpacing.sm),
            // Wrap et non Row : sur un téléphone étroit, une pastille « arrive plus
            // tard » assortie d'une heure et de trois accompagnants dépasse la largeur
            // disponible et provoquerait un débordement.
            Wrap(
              spacing: PpSpacing.sm,
              runSpacing: PpSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PpStatusChip(
                  presence: versPastille(membre.statut),
                  heure: membre.heureArrivee ?? membre.heureDepart,
                ),
                if (membre.accompagnants > 0)
                  Text(
                    l10n.invitesAccompagnants(membre.accompagnants),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            // EF-PRES-03 — chacun ne modifie que son propre statut.
            if (membre.cestMoi) ...[
              const SizedBox(height: PpSpacing.sm),
              _Accompagnants(evenementId: evenementId, membre: membre),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerExclusion(BuildContext context, WidgetRef ref) async {
    final l10n = PpL10n.of(context);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.invitesExclure),
        // RG-ROLE-03 : l'exclusion horodate la ligne sans la supprimer. Le dire ici
        // évite que l'organisateur croie effacer une dette en excluant quelqu'un.
        content: Text(l10n.invitesExclureConfirmation(membre.nomAffiche)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.paramAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.invitesExclure),
          ),
        ],
      ),
    );

    if (confirme != true) {
      return;
    }

    await ref.read(evenementsApiProvider).exclure(evenementId, membre.id);
    ref
      ..invalidate(membresProvider(evenementId))
      ..invalidate(evenementProvider(evenementId));
  }
}

/// Réglage des accompagnants, plafonnés à dix (EF-PRES-06).
class _Accompagnants extends ConsumerWidget {
  const _Accompagnants({required this.evenementId, required this.membre});

  /// Au-delà de dix, il s'agit d'un autre événement.
  static const plafond = 10;

  final String evenementId;
  final Membre membre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final auPlafond = membre.accompagnants >= plafond;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible : le libellé cède la place aux commandes plutôt que de pousser
            // la ligne au-delà de la largeur de l'écran.
            Flexible(
              child: Text(
                l10n.invitesAccompagnantsTitre,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('accompagnant-moins'),
              tooltip: '−',
              onPressed: membre.accompagnants == 0
                  ? null
                  : () => _regler(context, ref, membre.accompagnants - 1),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text('${membre.accompagnants}'),
            IconButton(
              key: const ValueKey('accompagnant-plus'),
              tooltip: '+',
              onPressed: auPlafond
                  ? null
                  : () => _regler(context, ref, membre.accompagnants + 1),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        if (auPlafond)
          Text(
            l10n.invitesAccompagnantsPlafond,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Future<void> _regler(BuildContext context, WidgetRef ref, int valeur) async {
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
            .majMaPresence(
              evenementId,
              statut: membre.statut,
              accompagnants: valeur,
            );

        ref
          ..invalidate(membresProvider(evenementId))
          ..invalidate(evenementProvider(evenementId));
      },
    );
  }
}
