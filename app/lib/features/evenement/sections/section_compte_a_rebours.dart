import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/models/evenement.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';
import '../../../l10n/generated/pp_localisations.dart';

/// Compte à rebours. Invisible une fois l'événement commencé : rien à décompter.
class SectionCompteARebours extends StatelessWidget {
  const SectionCompteARebours({required this.resume, super.key});

  final ResumeEvenement resume;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final maintenant = DateTime.now();

    if (!resume.debut.isAfter(maintenant)) {
      return const SizedBox.shrink();
    }

    final jours = joursCalendairesJusqua(resume.debut, depuis: maintenant);

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.md),
      child: PpCard(
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: PpColors.violet),
            const SizedBox(width: PpSpacing.md),
            Text(
              l10n.tdbDansNJours(jours),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
