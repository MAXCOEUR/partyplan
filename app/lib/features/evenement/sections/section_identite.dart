import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/evenement.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';

/// Nom, date et lieu de l'événement. Toujours visible.
class SectionIdentite extends StatelessWidget {
  const SectionIdentite({required this.resume, super.key});

  static final _dateFr = DateFormat('EEEE d MMMM yyyy, HH:mm', 'fr_FR');

  final ResumeEvenement resume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(resume.nom, style: theme.textTheme.headlineSmall),
          const SizedBox(height: PpSpacing.sm),
          _Ligne(
            icone: Icons.event_rounded,
            texte: _dateFr.format(resume.debut),
          ),
          if (resume.adresse != null)
            _Ligne(icone: Icons.place_outlined, texte: resume.adresse!),
          if (resume.description != null && resume.description!.isNotEmpty) ...[
            const SizedBox(height: PpSpacing.md),
            Text(resume.description!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PpSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18),
        const SizedBox(width: PpSpacing.sm),
        Expanded(
          child: Text(texte, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
