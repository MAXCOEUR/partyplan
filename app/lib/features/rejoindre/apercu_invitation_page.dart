import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/models/invitation.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/marque.dart';

/// Aperçu restreint d'une invitation, accessible sans session (RG-INV-04).
///
/// N'affiche que ce que porte [ApercuInvitation] : nom, date, lieu, nombre de
/// participants. **Ni liste nominative, ni dépenses, ni jeton.** Ce qui n'existe pas
/// dans le modèle ne peut pas fuiter dans cet écran.
class ApercuInvitationPage extends ConsumerWidget {
  const ApercuInvitationPage({this.jeton, this.code, super.key});

  static final _dateFr = DateFormat('EEEE d MMMM yyyy, HH:mm', 'fr_FR');

  final String? jeton;
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final apercu = ref.watch(apercuInvitationProvider((jeton: jeton, code: code)));

    return Scaffold(
      appBar: AppBar(title: const Text(PpMarque.nom)),
      body: apercu.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: l10n.apercuIntrouvable,
          onRetry: () =>
              ref.invalidate(apercuInvitationProvider((jeton: jeton, code: code))),
        ),
        data: (donnees) => _Contenu(
          apercu: donnees,
          jeton: jeton,
          code: code,
          dateFr: _dateFr,
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.apercu,
    required this.jeton,
    required this.code,
    required this.dateFr,
  });

  final ApercuInvitation apercu;
  final String? jeton;
  final String? code;
  final DateFormat dateFr;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      children: [
        PpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(apercu.nom, style: theme.textTheme.headlineSmall),
              const SizedBox(height: PpSpacing.sm),
              Text(dateFr.format(apercu.debut), style: theme.textTheme.bodyMedium),
              if (apercu.adresse != null)
                Text(apercu.adresse!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: PpSpacing.md),
              Text(
                l10n.apercuParticipants(apercu.nombreParticipants),
                style: theme.textTheme.bodySmall,
              ),
              if (apercu.description != null &&
                  apercu.description!.isNotEmpty) ...[
                const SizedBox(height: PpSpacing.md),
                Text(apercu.description!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.xl),
        if (apercu.dejaMembre)
          FilledButton(
            onPressed: () => context.go(PpRoutes.accueil),
            child: Text(l10n.apercuVoirEvenement),
          )
        else if (!apercu.adhesionsOuvertes)
          // EF-INV-06 — l'aperçu reste lisible et explique le refus, plutôt que de
          // renvoyer une erreur opaque.
          PpCard(
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: PpColors.orange),
                const SizedBox(width: PpSpacing.md),
                Expanded(child: Text(l10n.apercuFermee)),
              ],
            ),
          )
        else
          FilledButton(
            onPressed: () => context.push(
              jeton != null
                  ? PpRoutes.versAdhesion(jeton!)
                  : PpRoutes.versAdhesionParCode(code!),
            ),
            child: Text(l10n.apercuParticiper),
          ),
      ],
    );
  }
}
