import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/evenement.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';

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
          ],
        ),
      ),
    );
  }
}
