import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/service_notifications.dart';
import '../../../core/providers.dart';
import '../../../design/components/pp_card.dart';
import '../../../design/tokens.dart';

/// Proposition d'activer les notifications — `RG-NOT-03`.
///
/// Placée sur le tableau de bord d'un événement, et nulle part ailleurs : c'est là qu'on
/// vient d'acquérir quelque chose à être notifié. Demander au premier lancement fait
/// refuser par réflexe, et un refus système ne se redemande pas.
///
/// La section disparaît dès que la question est tranchée, dans un sens ou dans l'autre.
class SectionNotifications extends ConsumerStatefulWidget {
  const SectionNotifications({super.key});

  @override
  ConsumerState<SectionNotifications> createState() =>
      _SectionNotificationsState();
}

class _SectionNotificationsState extends ConsumerState<SectionNotifications> {
  EtatNotifications? _etat;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    final etat = await ref.read(serviceNotificationsProvider).etatCourant();
    if (mounted) {
      setState(() => _etat = etat);
    }
  }

  Future<void> _activer() async {
    await ref.read(serviceNotificationsProvider).demanderEtEnregistrer();
    await _lire();
  }

  @override
  Widget build(BuildContext context) {
    if (_etat != EtatNotifications.aDemander) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.md),
      child: PpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Être prévenu', style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.xs),
            Text(
              'Un changement de date, une réponse, un message : '
              'on te le fait savoir sans que tu aies à revenir voir.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('notifications-activer'),
                onPressed: _activer,
                child: const Text('Activer les notifications'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
