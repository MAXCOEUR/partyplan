import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/evenement.dart';
import '../../../core/models/membre.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_avatar.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/components/pp_status_chip.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';
import '../presence_vers_pastille.dart';

/// Synthèse des présences (EF-PRES-05).
///
/// Affiche **deux** décomptes distincts : les présents, qui comptent des personnes, et
/// les têtes, qui comptent les accompagnants (RG-PRES-04). Les confondre fausserait
/// toutes les quantités de courses. Les « peut-être » sont annoncés à part (RG-PRES-03).
class SectionSynthesePresences extends ConsumerWidget {
  const SectionSynthesePresences({
    required this.evenementId,
    required this.resume,
    super.key,
  });

  final String evenementId;
  final ResumeEvenement resume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);
    final membres = ref.watch(membresProvider(evenementId));

    final tetes = membres.maybeWhen(
      data: (liste) => liste.fold(0, (total, m) => total + m.tetes),
      orElse: () => null,
    );

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.presencesSurInvites(
                resume.nombrePresents,
                resume.nombreMembres,
              ),
              style: theme.textTheme.titleMedium,
            ),
            if (resume.nombrePeutEtre > 0)
              Text(
                l10n.peutEtreSuffixe(resume.nombrePeutEtre),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PpColors.orangeTexte,
                ),
              ),
            if (tetes != null && tetes != resume.nombrePresents) ...[
              const SizedBox(height: PpSpacing.xs),
              Text(l10n.tetesAPrevoir(tetes), style: theme.textTheme.bodySmall),
            ],
            // Le décompte ne dit pas qui vient : c'est la question la plus posée en
            // préparant une soirée, et y répondre demandait d'ouvrir un autre écran.
            ...membres.maybeWhen(
              data: (liste) => [
                const SizedBox(height: PpSpacing.md),
                const Divider(height: 1),
                for (final membre in _ordonner(liste))
                  _LigneParticipant(membre: membre),
              ],
              orElse: () => const <Widget>[],
            ),
          ],
        ),
      ),
    );
  }

  /// Présents d'abord, puis « peut-être », puis absents, puis sans réponse.
  ///
  /// On cherche d'abord qui vient : mêler les sans-réponse aux présents obligerait à
  /// lire chaque ligne pour faire le compte. À rang égal, l'ordre d'adhésion est
  /// conservé — celui du serveur.
  static List<Membre> _ordonner(List<Membre> membres) {
    int rang(StatutPresence statut) => switch (statut) {
      StatutPresence.present => 0,
      StatutPresence.enRetard => 1,
      StatutPresence.partAvant => 1,
      StatutPresence.peutEtre => 2,
      StatutPresence.absent => 3,
      StatutPresence.inconnu => 4,
    };

    final ordonnes = [...membres];
    ordonnes.sort((a, b) => rang(a.statut).compareTo(rang(b.statut)));

    return ordonnes;
  }
}

/// Un participant et sa réponse.
class _LigneParticipant extends StatelessWidget {
  const _LigneParticipant({required this.membre});

  final Membre membre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PpSpacing.xs),
      child: Row(
        children: [
          PpAvatar(nom: membre.nomAffiche, urlPhoto: membre.avatarUrl, taille: 32),
          const SizedBox(width: PpSpacing.md),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    membre.cestMoi ? 'Moi' : membre.nomAffiche,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // RG-PRES-04 : les accompagnants comptent pour les courses. Une ligne
                // qui ne les annonce pas fait acheter pour trop peu de monde.
                if (membre.accompagnants > 0) ...[
                  const SizedBox(width: PpSpacing.xs),
                  Text(
                    '+${membre.accompagnants}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: PpColors.texteSur(PpColors.violet, theme.brightness),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PpStatusChip(
            presence: versPastille(membre.statut),
            heure: membre.heureArrivee ?? membre.heureDepart,
          ),
        ],
      ),
    );
  }
}
