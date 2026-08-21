import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tokens.dart';

/// Choix d'une date et d'une heure, en JJ/MM/AAAA.
///
/// Deux boutons côte à côte plutôt qu'un champ de saisie : personne ne tape une date
/// correctement du premier coup sur un téléphone, et un champ libre impose de valider
/// un format.
///
/// Partagé entre la création d'un événement et ses paramètres : une date fixée à la
/// création se décale souvent d'un jour ou d'une heure, et le geste doit être le même
/// aux deux endroits.
class PpChoixDateHeure extends StatelessWidget {
  const PpChoixDateHeure({
    required this.libelle,
    required this.valeur,
    required this.format,
    required this.onChange,
    this.minimum,
    super.key,
  });

  final String libelle;
  final DateTime? valeur;
  final DateFormat format;
  final DateTime? minimum;
  final void Function(DateTime) onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courant = valeur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(libelle, style: theme.textTheme.labelLarge),
        const SizedBox(height: PpSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _choisir(context),
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(courant == null ? '—' : format.format(courant)),
              ),
            ),
            const SizedBox(width: PpSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _choisir(context),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  courant == null
                      ? '—'
                      : '${courant.hour.toString().padLeft(2, '0')}:'
                            '${courant.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _choisir(BuildContext context) async {
    final depart = valeur ?? minimum ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: depart,
      firstDate: minimum ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date == null || !context.mounted) {
      return;
    }

    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(depart),
    );

    onChange(
      DateTime(
        date.year,
        date.month,
        date.day,
        heure?.hour ?? depart.hour,
        heure?.minute ?? depart.minute,
      ),
    );
  }
}
